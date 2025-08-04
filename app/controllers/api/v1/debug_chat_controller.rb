# frozen_string_literal: true

module Api
  module V1
    class DebugChatController < ApplicationController
      include ActionController::Live
      
      def create
        response.headers['Content-Type'] = 'text/event-stream'
        response.headers['Cache-Control'] = 'no-cache'
        response.headers['X-Accel-Buffering'] = 'no'
        
        begin
          message = params.dig(:chat, :message) || "Hello"
          Rails.logger.info "Debug chat request: #{message}"
          
          # Test OpenAI without context
          api_key = ENV['OPENAI_API_KEY']
          
          if api_key.nil? || api_key.empty?
            response.stream.write "data: #{JSON.generate("ERROR: OpenAI API key not set")}\n\n"
            response.stream.write "data: [DONE]\n\n"
            return
          end
          
          client = OpenAI::Client.new(api_key: api_key)
          
          # Simple test prompt
          response_params = {
            model: "gpt-4.1-mini",
            messages: [
              {
                role: "system",
                content: "You are a helpful assistant. Keep responses brief."
              },
              {
                role: "user",
                content: message
              }
            ],
            temperature: 0.7,
            max_tokens: 200
          }
          
          # Try streaming
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
          Rails.logger.error "Debug chat error: #{e.message}"
          Rails.logger.error e.backtrace.first(5).join("\n")
          response.stream.write "data: #{JSON.generate("ERROR: #{e.message}")}\n\n"
          response.stream.write "data: [DONE]\n\n"
        ensure
          response.stream.close
        end
      end
    end
  end
end