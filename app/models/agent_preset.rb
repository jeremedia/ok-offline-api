class AgentPreset < ApplicationRecord
  # Validations
  validates :name, presence: true, uniqueness: true
  validates :category, presence: true
  validates :config_json, presence: true
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_category, ->(category) { where(category: category) }
  
  # Categories
  CATEGORIES = %w[
    enliteracy
    creative
    analytical
    technical
    conversational
    research
    specialized
  ].freeze
  
  validates :category, inclusion: { in: CATEGORIES }
  
  # Instance Methods
  def to_agent(agent_name = nil)
    agent = Agent.new(config_json)
    agent.name = agent_name || "#{name}_#{Time.current.to_i}"
    agent
  end
  
  def apply_to_agent(agent)
    config_json.each do |key, value|
      agent.send("#{key}=", value) if agent.respond_to?("#{key}=")
    end
    agent
  end
end