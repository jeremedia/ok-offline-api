class AgentConfigurationService
  class InvalidConfigurationError < StandardError; end
  
  # Build OpenAI-compatible parameters from Agent model
  def self.build_params(agent, context = {})
    new(agent, context).build_params
  end
  
  # Validate agent configuration
  def self.validate(agent)
    new(agent).validate
  end
  
  # Clone an agent with modifications
  def self.duplicate(agent, new_name, modifications = {})
    new(agent).duplicate(new_name, modifications)
  end
  
  def initialize(agent, context = {})
    @agent = agent
    @context = context
  end
  
  def build_params
    validate
    @agent.to_openai_params(@context)
  end
  
  def validate
    errors = []
    
    # Validate model compatibility
    if @agent.has_reasoning? && !@agent.model.start_with?("o")
      errors << "Reasoning configuration is only supported for o-series models"
    end
    
    # Validate MCP tools
    if @agent.has_mcp_tools?
      validate_mcp_tools(errors)
    end
    
    # Validate background mode
    if @agent.supports_background && @agent.has_mcp_tools?
      errors << "Background mode is not compatible with MCP tools"
    end
    
    # Validate JSON schema if present
    if @agent.supports_json_output?
      validate_json_schema(errors)
    end
    
    # Validate tool choice
    if @agent.specific_tool_choice? && @agent.tools_config.empty?
      errors << "Specific tool choice requires tools to be configured"
    end
    
    raise InvalidConfigurationError, errors.join("; ") if errors.any?
    
    true
  end
  
  def duplicate(new_name, modifications = {})
    new_agent = @agent.duplicate(new_name)
    
    modifications.each do |key, value|
      if new_agent.respond_to?("#{key}=")
        new_agent.send("#{key}=", value)
      end
    end
    
    new_agent.save!
    new_agent
  end
  
  private
  
  def validate_mcp_tools(errors)
    @agent.tools_config.each do |tool|
      next unless tool["type"] == "mcp"
      
      if tool["server_url"].blank?
        errors << "MCP tool missing server_url"
      end
      
      if tool["server_label"].blank?
        errors << "MCP tool missing server_label"
      end
      
      # Validate MCP server accessibility
      begin
        uri = URI.parse(tool["server_url"])
        unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
          errors << "MCP server URL must be HTTP or HTTPS: #{tool["server_url"]}"
        end
      rescue URI::InvalidURIError
        errors << "Invalid MCP server URL: #{tool["server_url"]}"
      end
    end
  end
  
  def validate_json_schema(errors)
    text_config = @agent.text_config
    return unless text_config.dig("format", "type") == "json_schema"
    
    schema = text_config.dig("format", "json_schema")
    if schema.blank?
      errors << "JSON schema format requires json_schema to be defined"
    end
    
    # Could add more detailed JSON schema validation here
  end
  
  # Helper method to merge agent presets
  def self.from_preset(preset_name, agent_name = nil, overrides = {})
    preset = AgentPreset.active.find_by!(name: preset_name)
    
    agent = preset.to_agent(agent_name)
    
    overrides.each do |key, value|
      agent.send("#{key}=", value) if agent.respond_to?("#{key}=")
    end
    
    agent
  end
  
  # Helper to build MCP tool configuration
  def self.build_mcp_tool(server_label:, server_url:, api_key: nil, require_approval: "never")
    tool = {
      type: "mcp",
      server_label: server_label,
      server_url: server_url,
      require_approval: require_approval
    }
    
    if api_key
      tool[:headers] = { "Authorization" => "Bearer #{api_key}" }
    end
    
    tool
  end
  
  # Helper to build function tool configuration
  def self.build_function_tool(name:, description:, parameters:)
    {
      type: "function",
      function: {
        name: name,
        description: description,
        parameters: parameters
      }
    }
  end
end