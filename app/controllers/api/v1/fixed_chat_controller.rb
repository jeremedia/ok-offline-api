# frozen_string_literal: true

module Api
  module V1
    class FixedChatController < ApplicationController
      include ActionController::Live
      
      before_action :set_cors_headers

      def create
        response.headers['Content-Type'] = 'text/event-stream'
        response.headers['Cache-Control'] = 'no-cache'
        response.headers['X-Accel-Buffering'] = 'no'
        
        begin
          Rails.logger.info "Chat request received: #{chat_params[:message]}"
          
          # Get vector search results for context
          context_results = get_search_context(chat_params[:message])
          
          # Stream the OpenAI response with context
          stream_response_with_context(chat_params[:message], context_results)
          
        rescue => e
          Rails.logger.error "Chat error: #{e.message}"
          Rails.logger.error e.backtrace.first(5).join("\n")
          response.stream.write "data: #{JSON.generate(error: e.message)}\n\n"
        ensure
          response.stream.close
        end
      end

      private

      def chat_params
        params.require(:chat).permit(:message)
      end

      def set_cors_headers
        headers['Access-Control-Allow-Origin'] = '*'
        headers['Access-Control-Allow-Methods'] = 'POST, OPTIONS'
        headers['Access-Control-Allow-Headers'] = 'Content-Type'
      end

      def get_search_context(query)
        # Simple vector search without pool extraction for now
        service = Search::VectorSearchService.new
        search_response = service.search(query: query, limit: 5)
        search_response[:results] || []
      rescue => e
        Rails.logger.error "Search error: #{e.message}"
        []
      end

      def stream_response_with_context(user_message, context_results)
        api_key = ENV['OPENAI_API_KEY']
        if api_key.nil? || api_key.empty?
          response.stream.write "data: #{JSON.generate(error: "OpenAI API key not configured")}\n\n"
          return
        end
        
        client = OpenAI::Client.new(api_key: api_key)
        
        # Build system prompt with context
        system_prompt = build_contextual_prompt(context_results)
        
        response_params = {
          model: "gpt-4.1-mini",
          messages: [
            { role: "system", content: system_prompt },
            { role: "user", content: user_message }
          ],
          temperature: 0.7,
          max_tokens: 1000
        }
        
        # Stream the response
        client.chat(
          parameters: response_params.merge(
            stream: proc do |chunk, _bytesize|
              if chunk.dig("choices", 0, "delta", "content")
                content = chunk.dig("choices", 0, "delta", "content")
                response.stream.write "data: #{content.to_json}\n\n"
              end
            end
          )
        )
        
        response.stream.write "data: [DONE]\n\n"
      rescue => e
        Rails.logger.error "OpenAI streaming error: #{e.message}"
        response.stream.write "data: #{JSON.generate(error: "Streaming failed: #{e.message}")}\n\n"
      end

      def build_contextual_prompt(context_results)
        prompt = <<~PROMPT
          You are the Burning Man Guide Assistant, helping participants navigate and understand Black Rock City.
          You have access to comprehensive data about camps, art, events, and the culture of Burning Man.
        PROMPT
        
        if context_results.any?
          prompt += "\n\nRelevant information from our database:\n"
          context_results.each do |item|
            prompt += "\n- #{item[:name]} (#{item[:type]})"
            if item[:description]
              prompt += ": #{item[:description].truncate(150)}"
            end
            if item[:metadata] && item[:metadata]['location_string']
              prompt += " [Location: #{item[:metadata]['location_string']}]"
            end
          end
        end
        
        prompt += <<~PROMPT
          
          
          Provide helpful, accurate information based on this context. Be conversational and embody the spirit of Burning Man.
          Include specific details like locations, times, and camp names when available.
          Keep your response concise and relevant to the question asked.
        PROMPT
        
        prompt
      end
    end
  end
end