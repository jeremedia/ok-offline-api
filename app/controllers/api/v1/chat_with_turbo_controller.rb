# frozen_string_literal: true

module Api
  module V1
    class ChatWithTurboController < ApplicationController
      include ActionController::Live
      
      before_action :set_cors_headers

      def create
        response.headers['Content-Type'] = 'text/vnd.turbo-stream.html; charset=utf-8'
        response.headers['X-Accel-Buffering'] = 'no'
        
        begin
          # Add user message via Turbo Stream
          response.stream.write turbo_stream.append('messages', 
            partial: 'chat/user_message', 
            locals: { message: chat_params[:message] }
          )
          
          # Generate unique message ID for assistant response
          message_id = "assistant-#{SecureRandom.hex(8)}"
          
          # Add empty assistant message container
          response.stream.write turbo_stream.append('messages',
            "<div id='#{message_id}' class='message assistant-message streaming'><div class='message-content'></div></div>"
          )
          
          # Search for context and stream response
          context = search_burning_man_context(chat_params[:message])
          stream_turbo_response(chat_params[:message], context, message_id)
          
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

      def search_burning_man_context(query)
        service = Search::VectorSearchService.new
        search_response = service.search(query: query, limit: 5)
        
        # Extract just the results array
        results = search_response[:results] || []
        
        pool_results = search_pools_for_context(query)
        
        {
          semantic_matches: results,
          pool_entities: pool_results
        }
      end

      def search_pools_for_context(query)
        extractor = Search::PoolEntityExtractionService.new
        query_entities = extractor.extract_pool_entities(query, 'query')
        
        related = {}
        return related unless query_entities
        
        query_entities.each do |pool, entities|
          next if entities.nil? || entities.empty?
          
          items = SearchableItem.joins(:search_entities)
                               .where(search_entities: { pool_name: pool, entity_name: entities })
                               .distinct
                               .limit(3)
          
          related[pool] = items if items.any?
        end
        
        related
      rescue => e
        Rails.logger.error "Pool search error: #{e.message}"
        {}
      end

      def stream_turbo_response(user_message, context, message_id)
        client = OpenAI::Client.new(api_key: ENV['OPENAI_API_KEY'])
        
        system_prompt = build_system_prompt(context)
        
        response_params = {
          model: "gpt-4.1-mini",
          messages: [
            { role: "system", content: system_prompt },
            { role: "user", content: user_message }
          ],
          temperature: 0.7,
          max_tokens: 1000
        }
        
        buffer = ""
        
        client.chat(
          parameters: response_params.merge(
            stream: proc do |chunk, _bytesize|
              if chunk.dig("choices", 0, "delta", "content")
                content = chunk.dig("choices", 0, "delta", "content")
                buffer += content
            
                # Update message content via Turbo Stream
                html_content = markdown_to_html(buffer)
                response.stream.write turbo_stream.update(
                  message_id,
                  "<div class='message-content'>#{html_content}</div>"
                )
              end
            end
          )
        )
        
        # Remove streaming class
        response.stream.write turbo_stream.replace(
          message_id,
          "<div id='#{message_id}' class='message assistant-message'><div class='message-content'>#{markdown_to_html(buffer)}</div></div>"
        )
        
        # Add entity highlights if relevant
        if context[:pool_entities].any?
          highlights = generate_entity_highlights(context[:pool_entities])
          response.stream.write turbo_stream.append(
            message_id,
            highlights
          )
        end
        
      rescue => e
        Rails.logger.error "Chat streaming error: #{e.message}"
        response.stream.write turbo_stream.update(
          message_id,
          "<div class='message-content error'>Sorry, I encountered an error. Please try again.</div>"
        )
      end

      def build_system_prompt(context)
        prompt = <<~PROMPT
          You are the Burning Man Guide Assistant, helping participants navigate and understand Black Rock City.
          You have access to comprehensive data about camps, art, events, and the culture of Burning Man.
          
          Relevant context from our database:
        PROMPT
        
        if context[:semantic_matches].present?
          prompt += "\n\nRelated items:\n"
          context[:semantic_matches].each do |item|
            prompt += "- #{item.name} (#{item.item_type}): #{item.description&.truncate(200)}\n"
            prompt += "  Location: #{item.location_string}\n" if item.location_string.present?
          end
        end
        
        if context[:pool_entities].present?
          prompt += "\n\nExtracted concepts from your query:\n"
          context[:pool_entities].each do |pool, items|
            prompt += "\n#{pool.to_s.titleize} aspects:\n"
            items.each do |item|
              prompt += "- #{item.name} (#{item.item_type})"
              prompt += " at #{item.location_string}" if item.location_string.present?
              prompt += "\n"
            end
          end
        end
        
        prompt += <<~PROMPT
          
          Provide helpful, accurate information based on this context. Be conversational and embody the spirit of Burning Man.
          Include specific details like locations, times, and camp names when available.
          If you're not sure about something, say so rather than making it up.
        PROMPT
        
        prompt
      end

      def markdown_to_html(text)
        text.gsub(/\*\*(.*?)\*\*/, '<strong>\1</strong>')
            .gsub(/\*(.*?)\*/, '<em>\1</em>')
            .gsub(/\n/, '<br>')
            .gsub(/'/, '&#39;')
            .gsub(/"/, '&quot;')
      end

      def generate_entity_highlights(pool_entities)
        html = "<div class='entity-highlights'><div class='pools-context'><h4>Related Concepts</h4>"
        
        pool_entities.each do |pool, items|
          html += "<div class='pool-group'>"
          html += "<h5>#{pool.to_s.titleize}</h5>"
          html += "<div class='entities'>"
          
          items.each do |item|
            html += "<a href='#' class='entity-link' data-item-id='#{item.id}'>#{CGI.escapeHTML(item.name)}</a>"
          end
          
          html += "</div></div>"
        end
        
        html += "</div></div>"
        html
      end
    end
  end
end