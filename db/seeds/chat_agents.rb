# Create default agents for chat endpoints

puts "Creating default chat agents..."

# Standard Chat Agent (without MCP tools)
Agent.find_or_create_by!(name: "chat_assistant") do |agent|
  agent.model = "gpt-4o-mini"
  agent.description = "Standard Burning Man chat assistant with vector search context"
  agent.temperature = 0.7
  agent.top_p = 1.0
  agent.max_output_tokens = 1000
  agent.instructions = <<~INSTRUCTIONS
    You are the Burning Man Guide Assistant, helping participants navigate and understand Black Rock City.
    You have access to comprehensive data about camps, art, events, and the culture of Burning Man.
    
    Provide helpful, accurate information based on the context provided. Be conversational and embody the spirit of Burning Man.
    Include specific details like locations, times, and camp names when available.
    Keep your response concise and relevant to the question asked.
    If asked about history or attendance years, use the year information provided.
  INSTRUCTIONS
  agent.metadata_template = {
    "service" => "chat",
    "context_type" => "vector_search"
  }
  agent.active = true
end

# MCP Chat Agent (with Seven Pools tools)
Agent.find_or_create_by!(name: "mcp_chat_assistant") do |agent|
  agent.model = "gpt-4.1"
  agent.description = "Seven Pools MCP-powered chat assistant"
  agent.temperature = 0.7
  agent.top_p = 0.95
  agent.instructions = <<~INSTRUCTIONS
    You are the Seven Pools Chat Assistant with direct access to the enliterated Burning Man dataset through the Model Context Protocol.
    
    You can:
    - Search camps, art, and events across all years
    - Analyze text for Seven Pools entities
    - Fetch detailed information about specific items
    - Discover cross-pool connections
    - Track location neighbors and camp movements
    - Embody specific personas when requested
    
    Use the MCP tools to provide grounded, accurate information. Always cite your sources and indicate which pools your information comes from.
  INSTRUCTIONS
  
  mcp_api_key = ENV['MCP_API_KEY'] || 'burning-man-seven-pools-2025'
  
  agent.tools_config = [
    {
      type: "mcp",
      server_label: "seven_pools",
      server_url: "https://offline.oknotok.com/api/v1/mcp/sse",
      headers: { "Authorization" => "Bearer #{mcp_api_key}" },
      require_approval: "never"
    }
  ]
  
  agent.metadata_template = {
    "service" => "mcp_chat",
    "pools_enabled" => "true"
  }
  
  agent.active = true
end

# Persona-enabled Chat Agent
Agent.find_or_create_by!(name: "persona_chat_assistant") do |agent|
  agent.model = "gpt-4o"
  agent.description = "Chat assistant with persona styling capabilities"
  agent.temperature = 0.8
  agent.top_p = 0.95
  agent.max_output_tokens = 1500
  
  agent.instructions_template = <<~INSTRUCTIONS
    You are the Burning Man Guide Assistant helping participants navigate and understand Black Rock City.
    
    {{#if persona_active}}
    STYLE GUIDANCE:
    - Embody the perspective and voice of {{persona_name}}
    - Use a {{persona_tone}} tone
    - Incorporate these key concepts naturally: {{persona_vocabulary}}
    - Style confidence: {{persona_confidence}}
    {{/if}}
    
    You have access to comprehensive data about camps, art, events, and the culture of Burning Man.
    Provide helpful, accurate information based on the context provided.
    Include specific details like locations, times, and camp names when available.
  INSTRUCTIONS
  
  agent.metadata_template = {
    "service" => "persona_chat",
    "persona_enabled" => "{{persona_active}}"
  }
  
  agent.active = true
end

puts "Chat agents created successfully!"
puts "- chat_assistant: Standard chat without MCP"
puts "- mcp_chat_assistant: Seven Pools MCP-powered chat"
puts "- persona_chat_assistant: Chat with persona styling"