class AgentUsage < ApplicationRecord
  belongs_to :agent
  
  # Validations
  validates :status, inclusion: { in: %w[pending in_progress completed failed] }
  
  # Scopes
  scope :completed, -> { where(status: "completed") }
  scope :failed, -> { where(status: "failed") }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user_id) { where(user_identifier: user_id) }
  scope :by_session, ->(session_id) { where(session_id: session_id) }
  scope :with_mcp_calls, -> { where("jsonb_array_length(mcp_calls) > 0") }
  
  # Callbacks
  before_save :calculate_costs
  
  # Constants for pricing (per 1M tokens)
  PRICING = {
    "gpt-4.1" => { input: 15.00, output: 60.00 },
    "gpt-4o" => { input: 5.00, output: 15.00 },
    "gpt-4o-mini" => { input: 0.15, output: 0.60 },
    "o3" => { input: 50.00, output: 200.00 },
    "o3-mini" => { input: 15.00, output: 60.00 }
  }.freeze
  
  # Class methods
  def self.total_cost_for_agent(agent_id)
    where(agent_id: agent_id).sum(:total_cost)
  end
  
  def self.usage_stats_for_agent(agent_id)
    stats = where(agent_id: agent_id).completed
    {
      total_requests: stats.count,
      total_tokens: stats.sum(:input_tokens) + stats.sum(:output_tokens),
      total_cost: stats.sum(:total_cost),
      average_execution_time: stats.average(:execution_time),
      mcp_calls_count: stats.sum("jsonb_array_length(mcp_calls)")
    }
  end
  
  # Instance methods
  def mark_completed!(response)
    self.status = "completed"
    self.response_id = response.id if response.respond_to?(:id)
    
    # Extract usage information
    if response.respond_to?(:usage)
      self.input_tokens = response.usage.input_tokens
      self.output_tokens = response.usage.output_tokens
      self.reasoning_tokens = response.usage.output_tokens_details&.reasoning_tokens || 0
    end
    
    # Extract tools used
    if response.respond_to?(:output)
      extract_tool_usage(response.output)
    end
    
    save!
  end
  
  def mark_failed!(error)
    self.status = "failed"
    self.error_message = error.message
    self.error_type = error.class.name
    save!
  end
  
  def duration
    return nil unless completed? && execution_time
    "#{execution_time.round(2)}s"
  end
  
  def completed?
    status == "completed"
  end
  
  def failed?
    status == "failed"
  end
  
  private
  
  def calculate_costs
    return unless input_tokens && output_tokens && agent
    
    model_pricing = PRICING[agent.model] || PRICING["gpt-4o"]
    
    self.input_cost = (input_tokens / 1_000_000.0) * model_pricing[:input]
    self.output_cost = (output_tokens / 1_000_000.0) * model_pricing[:output]
    self.total_cost = input_cost + output_cost
  end
  
  def extract_tool_usage(output_items)
    return unless output_items.is_a?(Array)
    
    tools = []
    mcp_calls_list = []
    
    output_items.each do |item|
      next unless item.respond_to?(:type)
      
      case item.type.to_s
      when "mcp_call"
        tool_name = item.respond_to?(:name) ? item.name : "unknown"
        tools << { type: "mcp", name: tool_name }
        mcp_calls_list << {
          name: tool_name,
          server: item.server_label || "unknown",
          timestamp: Time.current.iso8601
        }
      when "function_call"
        tools << { type: "function", name: item.function.name }
      when "code_interpreter_call"
        tools << { type: "code_interpreter" }
      when "file_search_call"
        tools << { type: "file_search" }
      when "web_search_call"
        tools << { type: "web_search" }
      end
    end
    
    self.tools_used = tools.uniq
    self.mcp_calls = mcp_calls_list
  end
end