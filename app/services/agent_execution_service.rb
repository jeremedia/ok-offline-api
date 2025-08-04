class AgentExecutionService
  class ExecutionError < StandardError; end
  
  def self.execute(agent, input, context = {})
    new(agent, context).execute(input)
  end
  
  def self.stream(agent, input, context = {}, response_stream:)
    new(agent, context).stream(input, response_stream: response_stream)
  end
  
  def initialize(agent, context = {})
    @agent = agent
    @context = context
    @client = OpenAI::Client.new(api_key: ENV["OPENAI_API_KEY"])
  end
  
  def execute(input)
    # Start usage tracking
    usage = @agent.agent_usages.create!(
      status: "in_progress",
      user_identifier: @context[:user_id],
      session_id: @context[:session_id],
      metadata: {
        input_preview: input.to_s.truncate(100),
        context_keys: @context.keys
      }
    )
    
    start_time = Time.current
    
    begin
      # Build parameters
      params = AgentConfigurationService.build_params(@agent, @context)
      params[:input] = input
      
      # Add previous response ID if continuing conversation
      if @context[:previous_response_id].present?
        params[:previous_response_id] = @context[:previous_response_id]
      end
      
      Rails.logger.info "Executing agent #{@agent.name} with params: #{params.except(:input).inspect}"
      
      # Execute based on streaming support and MCP tool presence
      response = if should_use_non_streaming?(params)
        @client.responses.create(params)
      else
        # For simple non-streaming without continuation
        @client.responses.create(params)
      end
      
      # Update usage tracking
      usage.execution_time = Time.current - start_time
      usage.mark_completed!(response)
      
      response
    rescue => e
      Rails.logger.error "Agent execution error: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      
      usage.execution_time = Time.current - start_time
      usage.mark_failed!(e)
      
      raise ExecutionError, "Agent execution failed: #{e.message}"
    end
  end
  
  def stream(input, response_stream:)
    # Start usage tracking
    usage = @agent.agent_usages.create!(
      status: "in_progress",
      user_identifier: @context[:user_id],
      session_id: @context[:session_id],
      metadata: {
        input_preview: input.to_s.truncate(100),
        context_keys: @context.keys,
        streaming: true
      }
    )
    
    start_time = Time.current
    
    begin
      # Build parameters
      params = AgentConfigurationService.build_params(@agent, @context)
      params[:input] = input
      
      # Add previous response ID if continuing conversation
      if @context[:previous_response_id].present?
        params[:previous_response_id] = @context[:previous_response_id]
      end
      
      Rails.logger.info "Streaming agent #{@agent.name} with params: #{params.except(:input).inspect}"
      
      # Handle streaming with MCP tool workaround
      if should_use_non_streaming?(params)
        # Use non-streaming create and manually stream the response
        response = @client.responses.create(params)
        stream_response_object(response, response_stream, usage)
      else
        # Use native streaming
        stream_response_native(params, response_stream, usage)
      end
      
      usage.execution_time = Time.current - start_time
      usage.save!
      
    rescue => e
      Rails.logger.error "Agent streaming error: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      
      usage.execution_time = Time.current - start_time
      usage.mark_failed!(e)
      
      response_stream.write "data: #{JSON.generate(error: e.message)}\n\n"
      response_stream.close rescue nil
      
      raise ExecutionError, "Agent streaming failed: #{e.message}"
    end
  end
  
  private
  
  def should_use_non_streaming?(params)
    # Use non-streaming for MCP tools with previous_response_id
    # because of the background mode limitation
    params[:previous_response_id].present? && 
    params[:tools]&.any? { |t| t[:type] == "mcp" || t["type"] == "mcp" }
  end
  
  def stream_response_native(params, response_stream, usage)
    response_id = nil
    mcp_tools_used = []
    
    stream = @client.responses.stream(params)
    
    stream.each do |event|
      case event
      when OpenAI::Streaming::ResponseTextDeltaEvent
        # Stream text delta
        response_stream.write "data: #{event.delta.to_json}\n\n"
        response_stream.flush if response_stream.respond_to?(:flush)
        
      when OpenAI::Models::Responses::ResponseOutputItemAddedEvent
        # Handle MCP tool activation
        if event.item.respond_to?(:type) && event.item.type.to_s == "mcp_call"
          if event.item.respond_to?(:name)
            tool_name = event.item.name
            response_stream.write "data: #{JSON.generate(type: 'tool_active', tool: tool_name)}\n\n"
            mcp_tools_used << { name: tool_name, timestamp: Time.current.iso8601 }
          end
        end
        
      when OpenAI::Models::Responses::ResponseMcpCallCompletedEvent
        # MCP tool completed
        response_stream.write "data: #{JSON.generate(type: 'tool_completed')}\n\n"
        
      when OpenAI::Streaming::ResponseCompletedEvent
        # Capture response details
        response_id = event.response.id
        
        # Update usage with final details
        if event.response.usage
          usage.input_tokens = event.response.usage.input_tokens
          usage.output_tokens = event.response.usage.output_tokens
          usage.reasoning_tokens = event.response.usage.output_tokens_details&.reasoning_tokens || 0
        end
        
        usage.response_id = response_id
        usage.mcp_calls = mcp_tools_used
        usage.status = "completed"
        
      when OpenAI::Models::Responses::ResponseErrorEvent
        Rails.logger.error "Response error: #{event.error}"
        response_stream.write "data: #{JSON.generate(error: event.error.message)}\n\n"
      end
    end
    
    # Send metadata
    metadata = {
      response_id: response_id,
      model: @agent.model,
      agent_name: @agent.name,
      mcp_tools_used: mcp_tools_used.size
    }
    response_stream.write "data: #{JSON.generate(type: 'metadata', data: metadata)}\n\n"
    response_stream.write "data: [DONE]\n\n"
    response_stream.close rescue nil
  end
  
  def stream_response_object(response_obj, response_stream, usage)
    # Manual streaming for non-streaming responses (MCP tool workaround)
    Rails.logger.info "Manual streaming for response: #{response_obj.id}"
    
    # Update usage from response
    usage.response_id = response_obj.id
    if response_obj.usage
      usage.input_tokens = response_obj.usage.input_tokens
      usage.output_tokens = response_obj.usage.output_tokens
      usage.reasoning_tokens = response_obj.usage.output_tokens_details&.reasoning_tokens || 0
    end
    
    mcp_tools_used = []
    
    # Stream the content
    if response_obj.output.present?
      response_obj.output.each do |output_item|
        case output_item.type.to_s
        when "message"
          # Stream message content
          if output_item.content.present?
            output_item.content.each do |content_item|
              if content_item.type.to_s == "output_text" && content_item.text.present?
                # Stream text in chunks
                text = content_item.text
                chunk_size = 10
                
                text.chars.each_slice(chunk_size) do |chunk|
                  response_stream.write "data: #{chunk.join.to_json}\n\n"
                  response_stream.flush if response_stream.respond_to?(:flush)
                  sleep(0.01) # Small delay to simulate streaming
                end
              end
            end
          end
          
        when "mcp_call"
          # Handle MCP tool calls
          tool_name = output_item.respond_to?(:name) ? output_item.name : "unknown"
          mcp_tools_used << { name: tool_name, timestamp: Time.current.iso8601 }
          
          response_stream.write "data: #{JSON.generate(type: 'tool_active', tool: tool_name)}\n\n"
          sleep(0.5) # Simulate tool execution
          response_stream.write "data: #{JSON.generate(type: 'tool_completed', tool: tool_name)}\n\n"
        end
      end
    end
    
    # Update usage
    usage.mcp_calls = mcp_tools_used
    usage.status = "completed"
    
    # Send metadata
    metadata = {
      response_id: response_obj.id,
      model: @agent.model,
      agent_name: @agent.name,
      mcp_tools_used: mcp_tools_used.size
    }
    response_stream.write "data: #{JSON.generate(type: 'metadata', data: metadata)}\n\n"
    response_stream.write "data: [DONE]\n\n"
    response_stream.close rescue nil
  end
end