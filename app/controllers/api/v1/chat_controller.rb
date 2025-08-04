# frozen_string_literal: true

module Api
  module V1
    class ChatController < ApplicationController
      include ActionController::Live
      
      before_action :set_cors_headers
      before_action :set_agent

      def create
        response.headers['Content-Type'] = 'text/event-stream'
        response.headers['Cache-Control'] = 'no-cache'
        response.headers['X-Accel-Buffering'] = 'no'
        
        begin
          Rails.logger.info "Chat request received: #{chat_params[:message]}"
          
          # Get both vector search and keyword search results
          context_results = get_enhanced_search_context(chat_params[:message])
          
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
        params.require(:chat).permit(:message, :agent_id)
      end

      def set_agent
        # Use agent_id from params or default to standard chat assistant
        agent_id = params.dig(:chat, :agent_id)
        
        @agent = if agent_id.present?
          Agent.active.find_by(id: agent_id)
        else
          Agent.active.find_by(name: "chat_assistant")
        end
        
        unless @agent
          render json: { error: "Agent not found or inactive" }, status: :not_found
        end
      end

      def set_cors_headers
        headers['Access-Control-Allow-Origin'] = '*'
        headers['Access-Control-Allow-Methods'] = 'POST, OPTIONS'
        headers['Access-Control-Allow-Headers'] = 'Content-Type'
      end

      def get_enhanced_search_context(query)
        service = Search::VectorSearchService.new
        
        # Get vector search results
        vector_results = service.search(query: query, limit: 5)[:results] || []
        
        # Also do keyword search for specific camps/entities mentioned
        keyword_results = []
        
        # Extract potential camp names from query (simple approach)
        words = query.split(/\s+/)
        words.each do |word|
          next if word.length < 4 # Skip short words
          
          # Search for exact camp name matches
          matches = SearchableItem
            .where('name ILIKE ?', "%#{word}%")
            .order(year: :desc)
            .limit(10)
          
          if matches.any?
            Rails.logger.info "Found #{matches.count} keyword matches for '#{word}'"
            
            matches.each do |item|
              keyword_results << {
                name: item.name,
                type: item.item_type,
                description: item.description,
                metadata: {
                  'year' => item.year,
                  'location_string' => item.location_string
                }
              }
            end
          end
        end
        
        # Combine and deduplicate results
        all_results = (vector_results + keyword_results).uniq { |r| "#{r[:name]}-#{r[:metadata]['year']}" }
        
        # Sort by year descending for camps
        all_results.sort_by { |r| -(r[:metadata]['year'] || 0) }
        
      rescue => e
        Rails.logger.error "Search error: #{e.message}"
        []
      end

      def stream_response_with_context(user_message, context_results)
        # Build context for the agent
        context = {
          user_id: request.remote_ip, # Could be actual user ID if authenticated
          session_id: request.session_options[:id],
          context_data: format_context_for_prompt(context_results)
        }
        
        # Check for active persona and add to context
        persona_style = get_active_persona_style
        if persona_style
          context.merge!(
            persona_active: "true",
            persona_name: persona_style[:persona_label] || "Unknown",
            persona_tone: persona_style[:tone] || "conversational",
            persona_vocabulary: (persona_style[:key_vocabulary] || []).join(", "),
            persona_confidence: persona_style[:confidence].to_s
          )
        else
          context[:persona_active] = "false"
        end
        
        # Use AgentExecutionService with streaming
        service = AgentExecutionService.new(@agent, context)
        
        # Format input to include context
        input_with_context = build_input_with_context(user_message, context_results)
        
        begin
          service.stream(input_with_context, response_stream: response.stream)
          # AgentExecutionService handles the [DONE] message
        rescue => e
          Rails.logger.error "Agent streaming error: #{e.message}"
          response.stream.write "data: #{JSON.generate(error: "Streaming failed: #{e.message}")}\n\n"
        end
      end

      def get_active_persona_style
        # Check cache for active persona (could also be session-based)
        persona_id = Rails.cache.read('active_persona')
        return nil unless persona_id
        
        cache_key = "style_capsule_#{persona_id}_public_#{Rails.application.config.x.persona_style.graph_version}_#{Rails.application.config.x.persona_style.lexicon_version}"
        Rails.cache.read(cache_key)
      end
      
      def use_reusable_prompt?
        ENV['OPENAI_REUSABLE_PROMPT_ID'].present?
      end
      
      def build_input_with_context(user_message, context_results)
        # Build a structured input that includes the user message and context
        input = "User Question: #{user_message}\n\n"
        
        if context_results.any?
          input += format_context_for_prompt(context_results)
        else
          input += "No specific context found in the database for this query."
        end
        
        input
      end
      
      def format_context_for_prompt(context_results)
        return "No relevant context found." unless context_results.any?
        
        formatted = "Relevant information from our database:\n"
        
        # Group by name to show history
        grouped = context_results.group_by { |r| r[:name] }
        
        grouped.each do |name, entries|
          if entries.size > 1
            years = entries.map { |e| e[:metadata]['year'] }.compact.sort
            formatted += "\n- #{name} has attended Burning Man in: #{years.join(', ')}"
            
            # Add most recent description
            latest = entries.max_by { |e| e[:metadata]['year'] || 0 }
            if latest[:description]
              formatted += "\n  Most recent (#{latest[:metadata]['year']}): #{latest[:description].truncate(150)}"
            end
          else
            entry = entries.first
            formatted += "\n- #{entry[:name]} (#{entry[:type]}, #{entry[:metadata]['year']})"
            if entry[:description]
              formatted += ": #{entry[:description].truncate(150)}"
            end
            if entry[:metadata] && entry[:metadata]['location_string']
              formatted += " [Location: #{entry[:metadata]['location_string']}]"
            end
          end
        end
        
        formatted
      end

      def build_contextual_prompt(context_results, persona_style = nil)
        prompt = <<~PROMPT
          You are the Burning Man Guide Assistant, helping participants navigate and understand Black Rock City.
          You have access to comprehensive data about camps, art, events, and the culture of Burning Man.
        PROMPT
        
        # Add persona styling if available
        if persona_style
          prompt += "\n\nSTYLE GUIDANCE:\n"
          prompt += "- Embody the perspective and voice of #{persona_style[:persona_label]}\n" if persona_style[:persona_label]
          prompt += "- Use a #{persona_style[:tone]} tone\n" if persona_style[:tone]
          prompt += "- Incorporate these key concepts naturally: #{persona_style[:key_vocabulary].join(', ')}\n" if persona_style[:key_vocabulary]&.any?
          prompt += "- Style confidence: #{persona_style[:confidence]}\n"
        end
        
        if context_results.any?
          prompt += "\n\nRelevant information from our database:\n"
          
          # Group by name to show history
          grouped = context_results.group_by { |r| r[:name] }
          
          grouped.each do |name, entries|
            if entries.size > 1
              years = entries.map { |e| e[:metadata]['year'] }.compact.sort
              prompt += "\n- #{name} has attended Burning Man in: #{years.join(', ')}"
              
              # Add most recent description
              latest = entries.max_by { |e| e[:metadata]['year'] || 0 }
              if latest[:description]
                prompt += "\n  Most recent (#{latest[:metadata]['year']}): #{latest[:description].truncate(150)}"
              end
            else
              entry = entries.first
              prompt += "\n- #{entry[:name]} (#{entry[:type]}, #{entry[:metadata]['year']})"
              if entry[:description]
                prompt += ": #{entry[:description].truncate(150)}"
              end
              if entry[:metadata] && entry[:metadata]['location_string']
                prompt += " [Location: #{entry[:metadata]['location_string']}]"
              end
            end
          end
        end
        
        prompt += <<~PROMPT
          
          
          Provide helpful, accurate information based on this context. Be conversational and embody the spirit of Burning Man.
          Include specific details like locations, times, and camp names when available.
          Keep your response concise and relevant to the question asked.
          If asked about history or attendance years, use the year information provided above.
        PROMPT
        
        prompt
      end
    end
  end
end