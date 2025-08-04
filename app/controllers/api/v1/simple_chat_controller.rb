# frozen_string_literal: true

module Api
  module V1
    class SimpleChatController < ApplicationController
      include ActionController::Live
      
      def create
        response.headers['Content-Type'] = 'text/event-stream'
        response.headers['Cache-Control'] = 'no-cache'
        response.headers['X-Accel-Buffering'] = 'no'
        
        begin
          message = params.dig(:chat, :message) || "Hello"
          Rails.logger.info "Simple chat request: #{message}"
          
          # Simple test response without OpenAI
          response.stream.write "data: #{JSON.generate("Testing")}\n\n"
          sleep 0.1
          response.stream.write "data: #{JSON.generate(" chat")}\n\n"
          sleep 0.1
          response.stream.write "data: #{JSON.generate(" interface")}\n\n"
          sleep 0.1
          response.stream.write "data: #{JSON.generate(" with")}\n\n"
          sleep 0.1
          response.stream.write "data: #{JSON.generate(" message:")}\n\n"
          sleep 0.1
          response.stream.write "data: #{JSON.generate(" #{message}")}\n\n"
          response.stream.write "data: [DONE]\n\n"
          
        rescue => e
          Rails.logger.error "Simple chat error: #{e.message}"
          response.stream.write "data: #{JSON.generate(error: e.message)}\n\n"
        ensure
          response.stream.close
        end
      end
    end
  end
end