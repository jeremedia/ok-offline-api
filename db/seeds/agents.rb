# Seed data for Agents and Agent Presets

puts "Creating Agent Presets..."

# Seven Pools Enliteracy Agent Preset
AgentPreset.find_or_create_by!(name: "seven_pools_analyst") do |preset|
  preset.category = "enliteracy"
  preset.description = "Analyzes content through the Seven Pools of Enliteracy framework"
  preset.config_json = {
    model: "gpt-4.1",
    temperature: 0.7,
    top_p: 0.95,
    instructions: "You are an expert in the Seven Pools of Enliteracy framework. You analyze content through the lens of: Idea (philosophical concepts), Manifest (physical creations), Experience (sensory/emotional), Relational (connections), Evolutionary (change over time), Practical (how-to knowledge), and Emanation (emergent wisdom). Ground your analysis in the data provided by the MCP tools.",
    tools_config: [
      {
        type: "mcp",
        server_label: "seven_pools",
        server_url: "https://offline.oknotok.com/api/v1/mcp/sse",
        headers: { "Authorization" => "Bearer #{ENV['MCP_API_KEY'] || 'burning-man-seven-pools-2025'}" },
        require_approval: "never"
      }
    ],
    supports_streaming: true,
    supports_background: false
  }
end

# Burning Man Persona Agent Preset
AgentPreset.find_or_create_by!(name: "burning_man_persona") do |preset|
  preset.category = "creative"
  preset.description = "Writes in the style of Burning Man personas like Larry Harvey"
  preset.config_json = {
    model: "gpt-4.1",
    temperature: 1.0,
    top_p: 0.95,
    max_output_tokens: 2000,
    instructions_template: "You are writing in the style of {{persona_name}}, drawing from their actual writings and speeches. Maintain their voice, perspective, and philosophical approach while being clear this is stylistic emulation, not impersonation.",
    tools_config: [
      {
        type: "mcp",
        server_label: "seven_pools",
        server_url: "https://offline.oknotok.com/api/v1/mcp/sse",
        headers: { "Authorization" => "Bearer #{ENV['MCP_API_KEY'] || 'burning-man-seven-pools-2025'}" },
        require_approval: "never"
      }
    ],
    metadata_template: {
      persona: "{{persona_name}}",
      style_confidence: "{{style_confidence}}"
    }
  }
end

# Data Analyst Agent Preset
AgentPreset.find_or_create_by!(name: "data_analyst") do |preset|
  preset.category = "analytical"
  preset.description = "Analyzes Burning Man data with structured outputs"
  preset.config_json = {
    model: "gpt-4o",
    temperature: 0.3,
    top_p: 0.8,
    instructions: "You are a data analyst specializing in Burning Man community data. Provide structured, factual analysis with clear insights. Use the search and analysis tools to ground your findings in actual data.",
    text_config: {
      format: {
        type: "json_schema",
        json_schema: {
          name: "data_analysis",
          schema: {
            type: "object",
            properties: {
              summary: { type: "string" },
              key_findings: {
                type: "array",
                items: { type: "string" }
              },
              data_points: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    metric: { type: "string" },
                    value: { type: "string" },
                    context: { type: "string" }
                  },
                  required: ["metric", "value"]
                }
              },
              recommendations: {
                type: "array",
                items: { type: "string" }
              }
            },
            required: ["summary", "key_findings"]
          }
        }
      }
    },
    tools_config: [
      {
        type: "mcp",
        server_label: "seven_pools",
        server_url: "https://offline.oknotok.com/api/v1/mcp/sse",
        headers: { "Authorization" => "Bearer #{ENV['MCP_API_KEY'] || 'burning-man-seven-pools-2025'}" },
        require_approval: "never"
      }
    ]
  }
end

# Creative Writer Agent Preset
AgentPreset.find_or_create_by!(name: "creative_writer") do |preset|
  preset.category = "creative"
  preset.description = "Creative writing with high temperature and diverse outputs"
  preset.config_json = {
    model: "gpt-4.1",
    temperature: 1.2,
    top_p: 0.95,
    max_output_tokens: 3000,
    instructions: "You are a creative writer inspired by the radical self-expression of Burning Man. Write vivid, imaginative content that captures the transformative spirit of Black Rock City.",
    supports_background: true,
    supports_streaming: true
  }
end

# Technical Assistant Agent Preset
AgentPreset.find_or_create_by!(name: "technical_assistant") do |preset|
  preset.category = "technical"
  preset.description = "Technical assistance with code and implementation"
  preset.config_json = {
    model: "gpt-4o",
    temperature: 0.2,
    top_p: 0.9,
    instructions: "You are a technical assistant helping with implementation details. Provide clear, accurate, and practical solutions. Focus on best practices and maintainable code.",
    tools_config: [
      {
        type: "code_interpreter"
      }
    ]
  }
end

# Research Agent Preset
AgentPreset.find_or_create_by!(name: "research_assistant") do |preset|
  preset.category = "research"
  preset.description = "Deep research with web search and file analysis"
  preset.config_json = {
    model: "gpt-4.1",
    temperature: 0.5,
    top_p: 0.9,
    instructions: "You are a research assistant specializing in Burning Man culture and history. Use all available tools to find comprehensive, accurate information. Cross-reference sources and provide citations.",
    tools_config: [
      {
        type: "web_search"
      },
      {
        type: "file_search"
      }
    ],
    include_options: ["file_search_call.results"]
  }
end

puts "Creating default Agents..."

# Create actual agent instances from presets

# Seven Pools Analyst Agent
seven_pools_preset = AgentPreset.find_by!(name: "seven_pools_analyst")
Agent.find_or_create_by!(name: "seven_pools_default") do |agent|
  seven_pools_preset.apply_to_agent(agent)
  agent.description = "Default Seven Pools analyst for enliteracy framework analysis"
  agent.active = true
end

# Larry Harvey Persona Agent
persona_preset = AgentPreset.find_by!(name: "burning_man_persona")
Agent.find_or_create_by!(name: "larry_harvey_style") do |agent|
  persona_preset.apply_to_agent(agent)
  agent.description = "Writes in the style of Larry Harvey based on his actual writings"
  agent.instructions = agent.instructions_template.gsub("{{persona_name}}", "Larry Harvey")
  agent.metadata_template = {
    "persona" => "Larry Harvey",
    "style_confidence" => "1.0"
  }
  agent.active = true
end

# Data Analysis Agent
data_preset = AgentPreset.find_by!(name: "data_analyst")
Agent.find_or_create_by!(name: "burning_man_data_analyst") do |agent|
  data_preset.apply_to_agent(agent)
  agent.description = "Analyzes Burning Man data with structured JSON outputs"
  agent.active = true
end

# O-series Reasoning Agent
Agent.find_or_create_by!(name: "deep_reasoning_analyst") do |agent|
  agent.model = "o3-mini"
  agent.description = "Deep reasoning analysis for complex Burning Man philosophical questions"
  agent.temperature = 0.7
  agent.instructions = "You are a philosophical analyst using deep reasoning to explore complex questions about Burning Man culture, principles, and community dynamics. Think step by step through problems."
  agent.reasoning_config = {
    effort: "medium",
    summary: true
  }
  agent.max_output_tokens = 5000
  agent.active = true
end

puts "Agents and presets created successfully!"
puts "- Created #{AgentPreset.count} agent presets"
puts "- Created #{Agent.count} agents"