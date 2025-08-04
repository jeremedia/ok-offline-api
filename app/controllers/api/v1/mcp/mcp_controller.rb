# frozen_string_literal: true

module Api
  module V1
    module Mcp
      class McpController < ApplicationController
      include ActionController::Live

      # SSE endpoint for MCP protocol (HTTP/SSE transport)
      def sse
        # For HTTP/SSE transport, auth is handled via headers on each request
        unless valid_mcp_auth?
          render json: { error: "Unauthorized" }, status: :unauthorized
          return
        end

        response.headers["Content-Type"] = "text/event-stream"
        response.headers["Cache-Control"] = "no-cache"
        response.headers["Connection"] = "keep-alive"
        response.headers["X-Accel-Buffering"] = "no"
        response.headers["Access-Control-Allow-Origin"] = "*"

        begin
          # Handle both GET (with params) and POST (with body) requests
          if request.get?
            # GET request - parameters are in the URL
            if params[:jsonrpc].present?
              message = {
                "jsonrpc" => params[:jsonrpc],
                "method" => params[:method],
                "id" => params[:id],
                "params" => params[:params] || {}
              }
            else
              # Empty GET request means client is establishing SSE connection
              response.stream.write(": MCP Server Ready\n\n")
              response.stream.close
              return
            end
          else
            # POST request - parameters are in the body
            request_body = request.body.read

            if request_body.blank?
              # Empty request means client is establishing SSE connection
              response.stream.write(": MCP Server Ready\n\n")
              response.stream.close
              return
            end

            message = JSON.parse(request_body)
          end
          Rails.logger.info "MCP Request: #{message['method']} (id: #{message['id']})"

          result = handle_mcp_message(message)

          # Send SSE formatted response with proper event structure
          response.stream.write("event: message\n")
          response.stream.write("data: #{result.to_json}\n\n")

        rescue JSON::ParserError => e
          error_response = {
            jsonrpc: "2.0",
            error: {
              code: -32700,
              message: "Parse error: #{e.message}"
            },
            id: nil
          }
          response.stream.write("event: error\n")
          response.stream.write("data: #{error_response.to_json}\n\n")
        rescue => e
          Rails.logger.error "MCP SSE error: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          error_response = {
            jsonrpc: "2.0",
            error: {
              code: -32603,
              message: "Internal error: #{e.message}"
            },
            id: message&.dig("id")
          }
          response.stream.write("event: error\n")
          response.stream.write("data: #{error_response.to_json}\n\n")
        ensure
          response.stream.close
        end
      end

      # REST endpoint for easier testing
      def tools
        message = JSON.parse(request.body.read)
        result = handle_mcp_message(message)
        render json: result
      rescue JSON::ParserError => e
        render json: { error: "Invalid JSON: #{e.message}" }, status: :bad_request
      rescue => e
        Rails.logger.error "MCP tools error: #{e.message}"
        render json: { error: "Server error: #{e.message}" }, status: :internal_server_error
      end

      private

      def handle_capabilities_request
        {
          jsonrpc: "2.0",
          result: {
            capabilities: {
              tools: {
                search: {
                  description: "Search across 461K+ entities in Seven Pools of Enliteracy",
                  inputSchema: {
                    type: "object",
                    properties: {
                      query: { type: "string", description: "Natural language search query" }
                    },
                    required: [ "query" ]
                  }
                },
                fetch: {
                  description: "Retrieve complete entity/item details with pool relationships",
                  inputSchema: {
                    type: "object",
                    properties: {
                      id: { type: "string", description: "Unique identifier for the item" }
                    },
                    required: [ "id" ]
                  }
                },
                analyze_pools: {
                  description: "Extract Seven Pools entities from new text in real-time",
                  inputSchema: {
                    type: "object",
                    properties: {
                      text: { type: "string", description: "Text content to analyze" }
                    },
                    required: [ "text" ]
                  }
                },
                pool_bridge: {
                  description: "Find items that bridge two pools with strong connections",
                  inputSchema: {
                    type: "object",
                    properties: {
                      pool1: { type: "string", description: "First pool name" },
                      pool2: { type: "string", description: "Second pool name" }
                    },
                    required: [ "pool1", "pool2" ]
                  }
                }
              }
            },
            serverInfo: {
              name: "Seven Pools MCP Server",
              version: "1.0.0",
              description: "AI-powered access to enliterated Burning Man dataset via Seven Pools framework"
            }
          }
        }
      end

      def handle_mcp_message(message)
        case message["method"]
        when "tools/call"
          handle_tool_call(message)
        when "tools/list"
          handle_tools_list_request(message)
        when "initialize"
          handle_initialize_request(message)
        else
          {
            jsonrpc: "2.0",
            error: {
              code: -32601,
              message: "Method not found: #{message['method']}"
            },
            id: message["id"]
          }
        end
      end

      def handle_tool_call(message)
        params = message["params"] || {}
        tool_name = params["name"]
        arguments = params["arguments"] || {}

        Rails.logger.info "Tool call: #{tool_name} with args: #{arguments.inspect}"

        case tool_name
        when "search"
          result = ::Mcp::SearchTool.call(**arguments.symbolize_keys)
        when "fetch"
          result = ::Mcp::FetchTool.call(**arguments.symbolize_keys)
        when "analyze_pools"
          result = ::Mcp::AnalyzePoolsTool.call(**arguments.symbolize_keys)
        when "pool_bridge"
          result = ::Mcp::PoolBridgeTool.call(**arguments.symbolize_keys)
        when "location_neighbors"
          result = ::Mcp::LocationNeighborsTool.call(**arguments.symbolize_keys)
        when "set_persona"
          result = ::Mcp::SetPersonaTool.call(**arguments.symbolize_keys)
        when "clear_persona"
          result = ::Mcp::ClearPersonaTool.call(**arguments.symbolize_keys)
        else
          return {
            jsonrpc: "2.0",
            error: {
              code: -32602,
              message: "Unknown tool: #{tool_name}"
            },
            id: message["id"]
          }
        end

        {
          jsonrpc: "2.0",
          result: {
            content: [
              {
                type: "text",
                text: result.to_json
              }
            ]
          },
          id: message["id"]
        }
      rescue => e
        Rails.logger.error "Tool call error (#{tool_name}): #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n")
        {
          jsonrpc: "2.0",
          error: {
            code: -32603,
            message: "Tool execution failed: #{e.message}"
          },
          id: message["id"]
        }
      end

      private

      def handle_initialize_request(message)
        # Support multiple protocol versions
        client_version = message.dig("params", "protocolVersion")
        supported_versions = [ "2025-03-26", "2025-06-18", "0.1.0" ]

        # Use the client's version if we support it, otherwise use latest
        protocol_version = supported_versions.include?(client_version) ? client_version : "2025-06-18"

        {
          jsonrpc: "2.0",
          result: {
            protocolVersion: protocol_version,
            capabilities: {
              tools: {},  # Empty object for newer protocol versions
              experimental: {}
            },
            serverInfo: {
              name: "Seven Pools MCP Server",
              version: "1.1.0",
              dataset: {
                items: 51391,
                entities: 461000
              },
              tools_available: 7,
              pools_supported: [ "idea", "manifest", "experience", "relational", "evolutionary", "practical", "emanation" ],
              capabilities: [ "semantic_search", "entity_extraction", "spatial_analysis", "temporal_tracking", "cross_pool_bridging", "persona_style" ],
              lexicon_version: "2025.07",
              embedding_version: "text-embedding-3-small",
              graph_version: "2025.07",
              last_ingest_at: "2025-08-01T12:00:00Z",
              privacy_default: "public",
              features: {
                persona_style: Rails.application.config.x.persona_style&.enabled || false
              },
              limits: {
                max_top_k: 50,
                max_relation_depth: 3,
                max_text_length: 8000
              },
              protocols: [ "2025-03-26", "2025-06-18", "0.1.0" ]
            }
          },
          id: message["id"]
        }
      end

      def handle_tools_list_request(message)
        {
          jsonrpc: "2.0",
          result: {
            tools: [
              {
                name: "search",
                description: "Unified semantic + graph search across the enliterated dataset",
                inputSchema: {
                  type: "object",
                  properties: {
                    query: { type: "string", description: "Natural language search query" },
                    top_k: { type: "integer", description: "Number of results (default 10, max 50)" },
                    pools: { type: "array", description: "Filter by specific pools", items: { type: "string" } },
                    date_from: { type: "string", description: "ISO8601 date filter" },
                    date_to: { type: "string", description: "ISO8601 date filter" },
                    require_rights: { type: "string", description: "Rights requirement (public/internal/any)" },
                    diversify_by_pool: { type: "boolean", description: "Diversify results by pool (default true)" },
                    include_trace: { type: "boolean", description: "Include trace paths (default true)" },
                    include_counts: { type: "boolean", description: "Include pool counts (default true)" }
                  },
                  required: [ "query" ]
                }
              },
              {
                name: "fetch",
                description: "Retrieve full entity details with pool relations",
                inputSchema: {
                  type: "object",
                  properties: {
                    id: { type: "string", description: "Unique identifier for the item" },
                    include_relations: { type: "boolean", description: "Include relationships (default true)" },
                    relation_depth: { type: "integer", description: "Relationship depth (default 1, max 3)" },
                    pools: { type: "array", description: "Limit relations to these pools", items: { type: "string" } },
                    as_of: { type: "string", description: "ISO8601 timestamp for time-travel read" }
                  },
                  required: [ "id" ]
                }
              },
              {
                name: "analyze_pools",
                description: "Extract and link pool entities from free text",
                inputSchema: {
                  type: "object",
                  properties: {
                    text: { type: "string", description: "Text content to analyze" },
                    mode: { type: "string", description: "Analysis mode (extract/classify/link, default extract)" },
                    link_threshold: { type: "number", description: "Linking confidence threshold (default 0.6)" }
                  },
                  required: [ "text" ]
                }
              },
              {
                name: "pool_bridge",
                description: "Find items that strongly connect two concepts or pools",
                inputSchema: {
                  type: "object",
                  properties: {
                    a: { type: "string", description: "Pool name, entity ID, or free text" },
                    b: { type: "string", description: "Pool name, entity ID, or free text" },
                    top_k: { type: "integer", description: "Number of results (default 10)" }
                  },
                  required: [ "a", "b" ]
                }
              },
              {
                name: "location_neighbors",
                description: "Find camps that were located near a target camp by year",
                inputSchema: {
                  type: "object",
                  properties: {
                    camp_name: { type: "string", description: "Name of the camp to analyze" },
                    year: { type: "integer", description: "Specific year to analyze (optional, analyzes all years if not provided)" },
                    radius: { type: "string", description: "Search radius: immediate, adjacent, or neighborhood (default: adjacent)" }
                  },
                  required: [ "camp_name" ]
                }
              },
              {
                name: "set_persona",
                description: "Set a persona style for responses based on dataset entities",
                inputSchema: {
                  type: "object",
                  properties: {
                    persona: { type: "string", description: "Persona name or ID (e.g., 'Larry Harvey' or 'person:larry_harvey')" },
                    style_mode: { type: "string", description: "Style strength: off, light, medium, strong (default: light)" },
                    style_scope: { type: "string", description: "Style application: narration_only, examples_only, full_answer (default: full_answer)" },
                    era: { type: "string", description: "Time period filter (e.g., '2000-2016', '2010', optional)" },
                    require_rights: { type: "string", description: "Rights requirement: public, internal, any (default: public)" },
                    max_quote_pct: { type: "number", description: "Maximum percentage of response that can be quotes (0.0-0.2, default: 0.1)" }
                  },
                  required: [ "persona" ]
                }
              },
              {
                name: "clear_persona",
                description: "Clear any active persona styling",
                inputSchema: {
                  type: "object",
                  properties: {},
                  required: []
                }
              }
            ]
          },
          id: message["id"]
        }
      end

      def valid_mcp_auth?
        # Accept either Bearer token or X-API-Key header
        auth_header = request.headers["Authorization"]
        api_key = request.headers["X-API-Key"]

        # For now, check against environment variable
        # In production, this should check against a database of valid API keys
        expected_key = ENV["MCP_API_KEY"] || "burning-man-seven-pools-2025"

        if auth_header&.start_with?("Bearer ")
          token = auth_header.split(" ").last
          return token == expected_key
        elsif api_key.present?
          return api_key == expected_key
        end

        false
      end
      end
    end
  end
end
