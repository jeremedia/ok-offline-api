# frozen_string_literal: true

module Api
  module V1
    # ResponsesChatController - Uses OpenAI Responses API with Remote MCP
    #
    # This controller demonstrates the future of AI chat interfaces:
    # Instead of manually handling tool calls and context, we let OpenAI
    # directly access our Seven Pools MCP server for real-time enliteracy.
    #
    # The Responses API automatically:
    # - Discovers our MCP tools (search, fetch, analyze_pools, pool_bridge)
    # - Calls them based on user queries
    # - Integrates results into the conversation
    # - Handles approval flows if needed
    class ResponsesChatController < ApplicationController
      include ActionController::Live

      before_action :set_cors_headers

      def create
        response.headers["Content-Type"] = "text/event-stream"
        response.headers["Cache-Control"] = "no-cache"
        response.headers["X-Accel-Buffering"] = "no"

        begin
          Rails.logger.info "Responses API chat request: #{chat_params[:message]}"

          # Create a response using Responses API with our MCP server
          stream_responses_api_chat(chat_params[:message])

        rescue => e
          Rails.logger.error "Responses chat error: #{e.message}"
          Rails.logger.error e.backtrace.first(5).join("\n")
          response.stream.write "data: #{JSON.generate(error: e.message)}\n\n"
        ensure
          response.stream.close
        end
      end

      private

      def chat_params
        params.require(:chat).permit(:message, :previous_response_id, :agent_id)
      end

      def set_cors_headers
        headers["Access-Control-Allow-Origin"] = "*"
        headers["Access-Control-Allow-Methods"] = "POST, OPTIONS"
        headers["Access-Control-Allow-Headers"] = "Content-Type"
      end

      def stream_responses_api_chat(user_message)
        api_key = ENV["OPENAI_API_KEY"]
        if api_key.nil? || api_key.empty?
          response.stream.write "data: #{JSON.generate(error: "OpenAI API key not configured")}\n\n"
          return
        end

        client = OpenAI::Client.new(api_key: api_key)

        # Check if using Agent model
        if chat_params[:agent_id].present?
          agent = Agent.active.find_by(id: chat_params[:agent_id])
          if agent.nil?
            response.stream.write "data: #{JSON.generate(error: "Agent not found")}\n\n"
            return
          end
          
          # Build context for agent
          context = {
            user_id: request.remote_ip, # Or use actual user ID if available
            session_id: request.session_options[:id],
            previous_response_id: chat_params[:previous_response_id]
          }
          
          # Use AgentExecutionService for streaming
          AgentExecutionService.stream(
            agent, 
            user_message, 
            context, 
            response_stream: response.stream
          )
          return
        end

        # Default behavior without agent (existing code)
        # MCP server configuration
        mcp_api_key = ENV["MCP_API_KEY"] || "burning-man-seven-pools-2025"

        response_params = {
          model: "gpt-4.1",
          tools: [
            {
              type: "mcp",
              server_label: "seven_pools",
              server_url: "https://offline.oknotok.com/api/v1/mcp/sse",
              headers: {
                "Authorization" => "Bearer #{mcp_api_key}"
              },
              require_approval: "never" # For dev - use approval flow in production
            }
          ],
          input: user_message, # Simple string input for subsequent turns
          store: true # Ensure responses are stored for conversation continuity
        }

        # The magic of previous_response_id - no need to manage conversation history!
        # OpenAI automatically includes all previous context
        if chat_params[:previous_response_id].present?
          response_params[:previous_response_id] = chat_params[:previous_response_id]
        else
          # Only on first message, provide system context
          response_params[:instructions] = build_system_instructions
          response_params[:input] = build_initial_input(user_message)
        end

        # Log the request for debugging
        Rails.logger.info "Calling Responses API with params: #{response_params.inspect}"

        # Use stream method for SSE responses
        # Note: When using MCP tools with previous_response_id, we need to use create + manual streaming
        # because background mode is not supported with MCP tools
        if chat_params[:previous_response_id].present?
          # For continuation, we'll use create (non-streaming) then manually stream the response
          response_obj = client.responses.create(response_params)
          stream_response_object(response_obj)
          return
        else
          stream = client.responses.stream(response_params)
        end

        response_id = nil
        mcp_tools_used = []
        mcp_tool_mapping = {} # Track item_id -> tool_name mapping

        # Add timeout to prevent hanging (60 seconds for MCP tool calls)
        Timeout.timeout(60) do
          stream.each do |event|
          case event
          when OpenAI::Streaming::ResponseTextDeltaEvent
            # Stream text delta to client
            response.stream.write "data: #{event.delta.to_json}\n\n"
            
            # Extract pool mentions from the text for real-time pool activation
            if event.delta.present?
              pool_names = extract_pool_mentions(event.delta)
              if pool_names.any?
                response.stream.write "data: #{JSON.generate(type: 'pools_mentioned', pools: pool_names)}\n\n"
              end
            end
          when OpenAI::Models::Responses::ResponseOutputItemAddedEvent
            # Handle when new output items are added (including MCP calls)
            if event.item.respond_to?(:type) && event.item.type.to_s == "mcp_call"
              if event.item.respond_to?(:name)
                tool_name = event.item.name
                Rails.logger.info "MCP tool added: #{tool_name} (item type: #{event.item.class})"
                
                # Send tool active event immediately when tool is added
                response.stream.write "data: #{JSON.generate(type: 'tool_active', tool: tool_name)}\n\n"
                
                # Track for later completion
                if event.item.respond_to?(:id)
                  mcp_tool_mapping[event.item.id] = { tool_name: tool_name, sent_active: true }
                end
              end
            end
          when OpenAI::Streaming::ResponseFunctionCallArgumentsDeltaEvent
            # Log function calls for debugging (handles both regular functions and MCP)
            Rails.logger.info "Function call arguments delta: #{event.delta}"
          when OpenAI::Models::Responses::ResponseMcpCallArgumentsDeltaEvent
            # Log MCP-specific tool calls
            Rails.logger.info "MCP tool call delta for item #{event.item_id}: #{event.delta}"
            
            # The delta contains the arguments being sent to the tool, not the tool name
            # We need to track this for later matching with the completed event
            begin
              if event.delta.present?
                mcp_tool_mapping[event.item_id] ||= { buffer: "", tool_name: nil, sent_active: false }
                mcp_tool_mapping[event.item_id][:buffer] += event.delta
                
                # Don't try to extract tool name from arguments - wait for completed event
                Rails.logger.info "Accumulating arguments for item #{event.item_id}"
              end
            rescue => e
              Rails.logger.warn "Error handling MCP delta: #{e.message}"
            end
          when OpenAI::Models::Responses::ResponseMcpCallCompletedEvent
            # MCP tool completed
            Rails.logger.info "MCP tool completed: item #{event.item_id}"
            
            # Get tool name from our mapping (should have been set by ResponseOutputItemAddedEvent)
            tool_name = mcp_tool_mapping.dig(event.item_id, :tool_name)
            
            if tool_name
              # Send completion event with specific tool name
              response.stream.write "data: #{JSON.generate(type: 'tool_completed', tool: tool_name)}\n\n"
              Rails.logger.info "Sent tool_completed for #{tool_name}"
            else
              Rails.logger.warn "No tool name found for completed MCP call #{event.item_id}"
            end
          when OpenAI::Streaming::ResponseCompletedEvent
            # Get final response details
            response_id = event.response.id
            Rails.logger.info "Response completed: #{response_id}"

            # Extract MCP tools used from the completed response
            if event.response.output
              event.response.output.each_with_index do |output, index|
                Rails.logger.info "Output #{index} - type: #{output.type}, class: #{output.class}"
                Rails.logger.info "Output details: #{output.inspect}"
                
                # Check for MCP calls specifically
                if output.respond_to?(:type) && output.type.to_s == "mcp_call"
                  # Try to get tool name from various possible properties
                  tool_name = if output.respond_to?(:name)
                    output.name
                  elsif output.respond_to?(:tool_name)
                    output.tool_name
                  elsif output.respond_to?(:function_name)
                    output.function_name
                  elsif output.respond_to?(:content) && output.content.is_a?(Array)
                    # Check if content has tool information
                    tool_info = output.content.find { |c| c.respond_to?(:name) }
                    tool_info&.name
                  else
                    "unknown"
                  end
                  
                  mcp_tools_used << {
                    tool: tool_name,
                    server: "seven_pools",
                    success: true
                  }
                  Rails.logger.info "Found MCP tool in completed response: #{tool_name}"
                  
                  # Don't send events here - they should have been sent earlier
                  # This is just for final tracking/metadata
                end
              end
            end
          when OpenAI::Models::Responses::ResponseErrorEvent
            Rails.logger.error "Response error: #{event.error}"
            response.stream.write "data: #{JSON.generate(error: event.error.message)}\n\n"
          end
          end
        end

        # Send response metadata
        metadata = {
          response_id: response_id,
          model: response_params[:model],
          mcp_tools_used: mcp_tools_used
        }
        response.stream.write "data: #{JSON.generate(type: 'metadata', data: metadata)}\n\n"

        response.stream.write "data: [DONE]\n\n"

      rescue => e
        Rails.logger.error "Responses API error: #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n")
        response.stream.write "data: #{JSON.generate(error: "API failed: #{e.message}")}\n\n"
      ensure
        response.stream.close rescue nil
      end

      def build_system_instructions
        <<~INSTRUCTIONS
          Enliterate Agent — System Prompt 
Concept grounding
Literate Technology: computing that communicates in natural language, explains its reasoning, adapts to user intent, and treats data as a partner in meaning rather than a passive store.
Enliteracy: the process that makes a dataset literate by mapping it into pools of meaning and the flows between them so the system can answer why, how, and what is next, not only what.
Pools for reasoning Seven core pools: Idea, Manifest, Experience, Relational, Evolutionary, Practical, Emanation. Enabling concepts: Provenance and Rights, Lexicon and Ontology, Intent and Task.
Environment and tools
Run against the Seven Pools MCP Server and ground answers in retrieved records.
analyze_pools(text, mode?, link_threshold?) → entities by pool, ambiguities, and a normalized_query via the Lexicon.
search(query, top_k?, pools?, date_from?, date_to?, require_rights?, diversify_by_pool?, include_trace?) → ranked items with pools_hit, trace, rights, provenance.
fetch(id, include_relations?, relation_depth?, pools?, as_of?) → full record, relations, timeline, rights, provenance.
pool_bridge(a, b, top_k?) → items that connect concepts with an explicit path across pools.
location_neighbors(camp_name, year?, radius?) → spatial placement analysis; neighbor lists by year, proximity classes, recurring neighbors, stability, sector preferences.
set_persona(persona, style_mode?, style_scope?, era?, require_rights?, max_quote_pct?) → resolve a dataset entity and return a rights‑aware Style Capsule (tone, cadence, vocabulary, devices, era, confidence, sources).
clear_persona() → turn persona styling off and clear any cached capsule.
Optional helpers: explain_path(ids[]), rights_check(ids[], intended_use).
Server info: Read version, limits, and defaults. Respect limits.max_top_k, max_relation_depth, and privacy_default.
Session options
presentation_mode: structured (default) | persona_narrative.
persona (optional): set via set_persona; write in the style of the persona without claiming identity; quotes require explicit rights.
persona_disclosure: silent (default) | inline.
silent: do not print any “in the style of …” line.
inline: on the first styled answer in a thread, print one short disclosure line.
Default behavior If a persona is active and the user did not specify, prefer presentation_mode=persona_narrative and persona_disclosure=silent.
Role
You are the Enliterate Agent, a language interface to a dataset modeled with the Seven Pools. Return grounded, cross‑pool, explainable answers that respect rights and privacy. In persona mode, keep the narrative primary and move scaffolding to endnotes.
Operating principles
Ground first: prefer retrieved facts to recall. Use analyze_pools then search before nontrivial claims.
Cross‑pool synthesis: weave at least two pools when the question calls for insight. Use pool_bridge to strengthen connections.
Show your path: include a short cross‑pool path using tool‑provided trace or path. Use relation verbs and distinct nodes (e.g., Idea → embodies → Manifest → elicits → Experience → connects via → Relational).
Cite cleanly: when asserting facts about items, include Citations: [Title, Year, ID].
Respect rights: honor require_rights and consent. Use rights_check before public deliverables or quoting.
Admit limits: if a pool is thin or conflicting, say so, name the gap, and propose a targeted search or data addition.
Style: clear, warm, direct. Short paragraphs. No em dashes. Define ambiguous terms from the Lexicon.
Safety: Practical guidance must be accurate and nonreckless. For medical or security matters, direct users to official services.
Determinism awareness: identical inputs should yield stable reasoning and ordering. Avoid speculative changes between turns.
Privacy: do not disclose personal Experience content without explicit consent flags.
Spatial fidelity: for neighbors, placement, sectors, or proximity questions, use location_neighbors instead of semantic guesses.
Persona integrity: write in the style without claiming identity; never fabricate quotes; downgrade style when confidence is low or rights restrict quoting.
Presentation flexibility: in persona_narrative, keep the narrative primary and move path, sources, rights, and spatial details to compact Endnotes.
Canonical naming: normalize to the Lexicon’s canonical names and casing in answers and citations; silently reconcile user input variants.
Source discipline: include specific roles, programs, or placements only if backed by fetched records; otherwise present as metaphor or omit.
Canonical Idea mapping: in cross‑pool paths, prefer Lexicon/Ten Principles canonical Idea names (e.g., Radical Self‑expression, Participation, Immediacy) over ad‑hoc phrasing.
Spatial endnote trigger: if the narrative mentions placement, street/sector, neighbor, or portal claims, call location_neighbors and include a Spatial endnote; otherwise omit the Spatial line.
Tool usage playbook
Disambiguate: run analyze_pools to map user language to canonical terms and produce a normalized_query.
Persona (optional): if style is requested, call set_persona. Use the Style Capsule to shape tone. If style_confidence < 0.6 or rights_summary.quotable=false and the user asked for strong style, explain briefly and reduce to light or neutral. Use clear_persona to turn styling off.
Discover: call search with top_k 6–10, diversify_by_pool=true. Filter by pools or dates when the intent is scoped.
Deepen: call fetch for items you will cite. Use relation_depth 1–2 for context. Use as_of for time‑bound questions.
Connect: use pool_bridge for “what links X and Y” or when you need multi‑pool connective tissue.
Locate neighbors: use location_neighbors for adjacency, sector, or multi‑year placement analysis; combine with fetch to cite specific camps and years.
Explain: if relations are nonobvious or you cite multiple items, call explain_path to present a compact sequence.
Validate rights: before publishable outputs, Experience narratives, or direct quotes, run rights_check with the intended use.
Cite specifics: when the narrative names concrete items (e.g., “3:30 & D,” named events), fetch and cite their [Title, Year, ID] or remove the specificity.
Disclosure control: only include a visible style note if persona_disclosure=inline or the user explicitly asks for disclosure.
Result ranking and synthesis
Favor results that increase pool coverage and reduce redundancy.
For Evolutionary questions, rank by time and describe change.
For Practical requests, prefer guidance validated by Experiences and note hazards.
For culture or ethos, anchor in Idea and Emanation, then illustrate with Manifest and Experience.
For Spatial questions, summarize neighbor patterns across years and sectors, highlight recurring neighbors, and state location stability.
When two items tie, prefer clearer rights and provenance.
Answer formats
A) Structured (default)
Intent: one line restating the user goal.
Answer: 2–8 sentences with specific examples.
Cross‑pool path: Pool A → relation → Pool B → relation → Pool C (use verbs and distinct nodes).
Citations: [Item Title, Year, ItemID] for each concrete claim.
Rights note: only when relevant, include license or visibility.
Spatial context: for spatial outputs, include years analyzed, sector preference, stability (e.g., highly mobile vs stable), and notable recurring neighbors.
Next steps: 1–3 bullets with searches, people, places, or delivery adapters to try.
B) Persona Narrative (optional, silent by default)
Narrative: 5–10 sentences in the persona’s style that directly answer the question. Integrate examples naturally. Avoid section headers unless the user asks.
Endnotes (single compact block):
Path: Idea → embodies → Manifest → elicits → Experience → connects via → Relational (or similar; use canonical Idea names).
Sources: [Title, Year, ID] (comma‑separated, 3–6 strongest).
Rights: echo tool results exactly (license, consent, visibility, attribution). If rights_check wasn’t called, do not guess the license.
Spatial: include when the narrative makes spatial claims (years analyzed; sector preference; stability; recurring neighbors from location_neighbors).
(If persona_disclosure=inline, prepend a single line: “In the style of {Persona}, not as them.”)
Refusal and uncertainty
If a claim is unsupported by fetched records, do not invent it. Name the missing pool or flow and offer a refined search.
If requested content is private, restricted, or under embargo, explain the rule and suggest public alternatives.
If the question is ambiguous, ask one brief clarifying question tied to pools or time.
Self‑check before replying
Did I use tool outputs rather than memory for facts.
Did I weave two or more pools when the user wanted synthesis.
Did I include a path string and citations for concrete claims.
Did I respect rights and consent.
Is the prose concise and clear.
In persona mode, did I keep the narrative primary and move scaffolding to endnotes.
Did I use location_neighbors for spatial adjacency or sector questions when spatial claims are present.
If persona styling is active, did I avoid impersonation, honor quoting rights, and keep style aligned with the capsule.
Did I normalize names to canonical Lexicon casing and cite any specific roles, programs, or placements I mentioned.
Did I map Idea names in the Path to canonical Lexicon/Ten Principles terms.
Do not
Guess dates, locations, or policies.
Dump long uncited lists when a short synthesis would do.
Answer from a single pool when the question calls for flows.
Expose restricted Experience content or ignore licenses.
Infer camp neighbors via semantic search; use location_neighbors for spatial adjacency.
Impersonate a persona or fabricate quotes; paraphrase when rights restrict quoting.
Add a visible persona disclosure unless persona_disclosure=inline or the user requests it.
        INSTRUCTIONS
      end

      def build_initial_input(user_message)
        # For the first message, we can provide structured input if needed
        # But keeping it simple for now - just the user's message
        user_message
      end

      def extract_mcp_tools_used(response)
        # Extract which MCP tools were called from the response
        tools_used = []

        response.output&.each do |item|
          if item["type"] == "mcp_call"
            tools_used << {
              tool: item["name"],
              server: item["server_label"],
              success: item["error"].nil?
            }
          end
        end

        tools_used
      end
      
      def extract_pool_mentions(text)
        return [] unless text.present?
        
        # Define pool keywords
        pool_patterns = {
          'idea' => /\b(idea|principle|philosophy|concept|belief|theory)\b/i,
          'manifest' => /\b(manifest|camp|art|structure|build|create|physical)\b/i,
          'experience' => /\b(experience|feel|emotion|transform|moment|story|sensation)\b/i,
          'relational' => /\b(relational|community|connect|relationship|together|social)\b/i,
          'evolutionary' => /\b(evolutionary|history|change|evolution|year|time|temporal)\b/i,
          'practical' => /\b(practical|how|guide|tip|skill|technique|instruction)\b/i,
          'emanation' => /\b(emanation|spiritual|transcend|wisdom|collective|emergence)\b/i
        }
        
        activated_pools = []
        pool_patterns.each do |pool, pattern|
          if text.match?(pattern)
            activated_pools << pool
          end
        end
        
        activated_pools
      end

      def stream_response_object(response_obj)
        # Stream a non-streaming response object manually
        Rails.logger.info "Streaming response object: #{response_obj.id}"
        Rails.logger.info "Response output: #{response_obj.output.inspect}"
        
        # Stream the text content
        if response_obj.output.present?
          response_obj.output.each_with_index do |output_item, index|
            Rails.logger.info "Output item #{index}: type=#{output_item.type}, class=#{output_item.class}"
            
            case output_item.type.to_s
            when "message"
              # Stream the message content
              Rails.logger.info "Processing message output"
              if output_item.content.present?
                output_item.content.each do |content_item|
                  Rails.logger.info "Content item: type=#{content_item.type rescue 'unknown'}, class=#{content_item.class}"
                  
                  # Handle different content types based on the type field
                  text = nil
                  if content_item.respond_to?(:type) && content_item.type.to_s == "output_text" && content_item.respond_to?(:text)
                    text = content_item.text
                  elsif content_item.respond_to?(:text)
                    text = content_item.text
                  elsif content_item.is_a?(Hash) && content_item["text"]
                    text = content_item["text"]
                  elsif content_item.is_a?(String)
                    text = content_item
                  end
                  
                  if text.present?
                    Rails.logger.info "Streaming text: #{text}"
                    # Stream text in chunks to simulate streaming
                    chunk_size = 10 # Characters per chunk
                    
                    text.chars.each_slice(chunk_size) do |chunk|
                      response.stream.write "data: #{chunk.join.to_json}\n\n"
                      response.stream.flush if response.stream.respond_to?(:flush)
                      sleep(0.01) # Small delay to simulate streaming
                    end
                    
                    # Check for pool mentions
                    pool_names = extract_pool_mentions(text)
                    if pool_names.any?
                      response.stream.write "data: #{JSON.generate(type: 'pools_mentioned', pools: pool_names)}\n\n"
                    end
                  else
                    Rails.logger.warn "No text found in content item: #{content_item.inspect}"
                  end
                end
              else
                Rails.logger.warn "No content in message output"
              end
            when "mcp_call"
              # Handle MCP tool calls
              tool_name = output_item.respond_to?(:name) ? output_item.name : "unknown"
              Rails.logger.info "MCP tool in response: #{tool_name}"
              
              # Send tool events
              response.stream.write "data: #{JSON.generate(type: 'tool_active', tool: tool_name)}\n\n"
              sleep(0.5) # Simulate tool execution
              response.stream.write "data: #{JSON.generate(type: 'tool_completed', tool: tool_name)}\n\n"
            else
              Rails.logger.info "Unknown output type: #{output_item.type}"
            end
          end
        else
          Rails.logger.warn "No output in response object"
        end
        
        # Send metadata
        mcp_tools_used = response_obj.output.select { |o| o.type.to_s == "mcp_call" }.map do |tool|
          { tool: tool.respond_to?(:name) ? tool.name : "unknown", server: "seven_pools", success: true }
        end
        
        metadata = {
          response_id: response_obj.id,
          model: response_obj.model,
          mcp_tools_used: mcp_tools_used
        }
        response.stream.write "data: #{JSON.generate(type: 'metadata', data: metadata)}\n\n"
        response.stream.write "data: [DONE]\n\n"
        
      rescue => e
        Rails.logger.error "Error streaming response object: #{e.message}"
        response.stream.write "data: #{JSON.generate(error: e.message)}\n\n"
      ensure
        response.stream.close rescue nil
      end
    end
  end
end
