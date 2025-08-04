class Agent < ApplicationRecord
  # Associations
  has_many :agent_usages, dependent: :destroy
  
  # Validations
  validates :name, presence: true, uniqueness: true
  validates :model, presence: true
  validates :temperature, numericality: { in: 0.0..2.0 }
  validates :top_p, numericality: { in: 0.0..1.0 }
  validates :top_logprobs, numericality: { in: 0..20 }, allow_nil: true
  validates :version, numericality: { greater_than: 0 }
  validates :tool_choice, inclusion: { in: %w[auto none required] }, unless: :specific_tool_choice?
  validates :service_tier, inclusion: { in: %w[auto default flex scale priority] }
  validates :truncation_strategy, inclusion: { in: %w[auto disabled] }
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :for_model, ->(model) { where(model: model) }
  scope :with_mcp_tools, -> { where("jsonb_array_length(tools_config) > 0 AND tools_config @> '[{\"type\": \"mcp\"}]'") }
  scope :with_streaming, -> { where(supports_streaming: true) }
  
  # Callbacks
  before_save :increment_version_if_changed
  
  # Instance Methods
  def has_mcp_tools?
    tools_config.any? { |tool| tool["type"] == "mcp" }
  end
  
  def has_reasoning?
    reasoning_config.present? && reasoning_config["effort"].present?
  end
  
  def supports_json_output?
    text_config.dig("format", "type").in?(["json_object", "json_schema"])
  end
  
  def specific_tool_choice?
    !tool_choice.in?(%w[auto none required])
  end
  
  def mcp_servers
    tools_config.select { |t| t["type"] == "mcp" }.map { |t| t["server_label"] }
  end
  
  def duplicate(new_name)
    new_agent = self.dup
    new_agent.name = new_name
    new_agent.version = 1
    new_agent.created_at = nil
    new_agent.updated_at = nil
    new_agent
  end
  
  def to_openai_params(context = {})
    params = {
      model: model,
      temperature: temperature,
      top_p: top_p,
      store: store_responses,
      service_tier: service_tier,
      truncation: truncation_strategy,
      parallel_tool_calls: parallel_tool_calls
    }
    
    # Add optional numeric parameters
    params[:top_logprobs] = top_logprobs if top_logprobs.present?
    params[:max_output_tokens] = max_output_tokens if max_output_tokens.present?
    params[:max_tool_calls] = max_tool_calls if max_tool_calls.present?
    
    # Add instructions
    if instructions_template.present?
      params[:instructions] = interpolate_template(instructions_template, context)
    elsif instructions.present?
      params[:instructions] = instructions
    end
    
    # Add tool configuration
    if tools_config.present? && tools_config.any?
      params[:tools] = tools_config
      params[:tool_choice] = tool_choice
    end
    
    # Add text configuration
    params[:text] = text_config if text_config.present?
    
    # Add reasoning configuration for o-series models
    params[:reasoning] = reasoning_config if has_reasoning?
    
    # Add include options
    params[:include] = include_options if include_options.present? && include_options.any?
    
    # Add metadata
    if metadata_template.present?
      params[:metadata] = interpolate_hash_template(metadata_template, context)
    end
    
    # Add safety identifier
    if safety_identifier_template.present? && context[:user_id].present?
      params[:safety_identifier] = interpolate_template(safety_identifier_template, context)
    end
    
    # Add prompt cache key
    if prompt_cache_key_template.present?
      params[:prompt_cache_key] = interpolate_template(prompt_cache_key_template, context)
    end
    
    # Handle background mode (not compatible with MCP tools)
    if supports_background && !has_mcp_tools?
      params[:background] = true
    end
    
    params
  end
  
  private
  
  def increment_version_if_changed
    if persisted? && changed? && !version_changed?
      self.version += 1
    end
  end
  
  def interpolate_template(template, context)
    template.gsub(/\{\{(\w+)\}\}/) do |match|
      key = $1.to_sym
      context[key] || match
    end
  end
  
  def interpolate_hash_template(hash_template, context)
    hash_template.transform_values do |value|
      if value.is_a?(String)
        interpolate_template(value, context)
      else
        value
      end
    end
  end
end