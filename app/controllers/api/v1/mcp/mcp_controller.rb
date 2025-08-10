# frozen_string_literal: true

# MCP (Model Context Protocol) Server Implementation
#
# This controller implements a complete MCP server in Rails using Server-Sent Events (SSE)
# for real-time communication with AI clients like ChatGPT, Claude, and custom applications.
#
# Architecture Overview:
# - JSON-RPC 2.0 protocol over HTTP/SSE
# - Stateless tool-based architecture
# - Real-time streaming responses
# - API key authentication
# - Graceful error handling
#
# For complete implementation guide, see:
# docs/RAILS_MCP_SERVER_IMPLEMENTATION_GUIDE.md
#
# Key endpoints:
# - GET/POST /api/v1/mcp/sse - Main SSE endpoint for MCP communication
# - POST /api/v1/mcp/tools - REST endpoint for testing (optional)
#
module Api
  module V1
    module Mcp
      class McpController < ApplicationController
      include ActionController::Live  # Required for Server-Sent Events support

      # Main SSE endpoint for MCP protocol communication
      #
      # Supports both GET and POST requests for maximum client compatibility:
      # - GET: Parameters in URL query string
      # - POST: JSON payload in request body
      #
      # Returns Server-Sent Events stream with JSON-RPC 2.0 responses
      #
      # Authentication: X-API-Key header or Authorization: Bearer token
      #
      # See implementation guide: Step 1 - Create the MCP Controller
      def sse
        # Authentication: Validate on every request (MCP is stateless)
        # See implementation guide: Step 1 - Add authentication
        unless valid_mcp_auth?
          render json: { error: "Unauthorized" }, status: :unauthorized
          return
        end

        # Configure Server-Sent Events headers
        # These headers are critical for proper SSE streaming
        # See implementation guide: Common Gotchas - SSE Buffering Issues
        response.headers["Content-Type"] = "text/event-stream"    # SSE content type
        response.headers["Cache-Control"] = "no-cache"              # Prevent caching
        response.headers["Connection"] = "keep-alive"              # Keep connection open
        response.headers["X-Accel-Buffering"] = "no"              # Disable nginx buffering
        response.headers["Access-Control-Allow-Origin"] = "*"      # CORS for SSE

        begin
          # Request parsing: Support both GET and POST for maximum client compatibility
          # See implementation guide: Step 1 - Handle request parsing
          if request.get?
            # GET request: JSON-RPC parameters in URL query string
            # Format: /mcp/sse?jsonrpc=2.0&method=tools/list&id=1
            if params[:jsonrpc].present?
              message = {
                "jsonrpc" => params[:jsonrpc],
                "method" => params[:method],
                "id" => params[:id],
                "params" => params[:params] || {}
              }
            else
              # Empty GET: Client establishing SSE connection (heartbeat/keepalive)
              response.stream.write(": MCP Server Ready\n\n")
              response.stream.close
              return
            end
          else
            # POST request: JSON-RPC message in request body (preferred method)
            request_body = request.body.read

            if request_body.blank?
              # Empty POST: Client establishing SSE connection
              response.stream.write(": MCP Server Ready\n\n")
              response.stream.close
              return
            end

            # Parse JSON-RPC 2.0 message
            message = JSON.parse(request_body)
          end
          # Log request for debugging and monitoring
          Rails.logger.info "MCP Request: #{message['method']} (id: #{message['id']})"

          # Route message to appropriate handler
          # See implementation guide: Step 2 - Implement Protocol Handlers
          result = handle_mcp_message(message)

          # Stream JSON-RPC response using Server-Sent Events format
          # SSE format: "event: eventname\ndata: payload\n\n"
          response.stream.write("event: message\n")
          response.stream.write("data: #{result.to_json}\n\n")

        # Error handling: JSON-RPC 2.0 error codes and SSE error events
        # See implementation guide: Common Gotchas - JSON Parsing Errors
        rescue JSON::ParserError => e
          # JSON-RPC 2.0 Parse Error (-32700)
          error_response = {
            jsonrpc: "2.0",
            error: {
              code: -32700,  # Standard JSON-RPC parse error code
              message: "Parse error: #{e.message}"
            },
            id: nil  # Cannot determine ID from malformed request
          }
          response.stream.write("event: error\n")
          response.stream.write("data: #{error_response.to_json}\n\n")
        rescue => e
          # Log full error details for debugging
          Rails.logger.error "MCP SSE error: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          
          # JSON-RPC 2.0 Internal Error (-32603)
          error_response = {
            jsonrpc: "2.0",
            error: {
              code: -32603,  # Standard JSON-RPC internal error code
              message: "Internal error: #{e.message}"
            },
            id: message&.dig("id")  # Preserve original request ID if available
          }
          response.stream.write("event: error\n")
          response.stream.write("data: #{error_response.to_json}\n\n")
        ensure
          # Critical: Always close SSE stream to prevent connection leaks
          # See implementation guide: Common Gotchas - Connection Management
          response.stream.close
        end
      end

      # Optional REST endpoint for testing MCP tools without SSE streaming
      #
      # This endpoint accepts the same JSON-RPC messages but returns regular HTTP responses
      # instead of Server-Sent Events. Useful for development and debugging.
      #
      # Usage:
      #   POST /api/v1/mcp/tools
      #   Content-Type: application/json
      #   X-API-Key: your-api-key
      #   Body: {"jsonrpc":"2.0","method":"tools/list","id":1}
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

      # Main message router: Dispatch JSON-RPC methods to appropriate handlers
      #
      # MCP Protocol Methods:
      # - initialize: Client handshake and capability negotiation
      # - tools/list: Return available tools and their schemas
      # - tools/call: Execute a specific tool with arguments
      #
      # See implementation guide: Step 2 - Implement Protocol Handlers
      def handle_mcp_message(message)
        case message["method"]
        when "tools/call"
          # Execute a tool with the provided arguments
          handle_tool_call(message)
        when "tools/list"
          # Return list of available tools and their input schemas
          handle_tools_list_request(message)
        when "initialize"
          # Handle client handshake and return server capabilities
          handle_initialize_request(message)
        else
          # JSON-RPC 2.0 Method Not Found error (-32601)
          {
            jsonrpc: "2.0",
            error: {
              code: -32601,  # Standard JSON-RPC method not found code
              message: "Method not found: #{message['method']}"
            },
            id: message["id"]
          }
        end
      end

      # Tool execution handler: Route tool calls to appropriate service classes
      #
      # MCP Tool Call Format:
      # {
      #   "jsonrpc": "2.0",
      #   "method": "tools/call",
      #   "params": {
      #     "name": "tool_name",
      #     "arguments": { "param1": "value1" }
      #   },
      #   "id": 1
      # }
      #
      # See implementation guide: Step 3 - Create Tool Services
      def handle_tool_call(message)
        params = message["params"] || {}
        tool_name = params["name"]
        arguments = params["arguments"] || {}

        # Log tool execution for monitoring and debugging
        Rails.logger.info "Tool call: #{tool_name} with args: #{arguments.inspect}"

        # Tool routing: Each tool is implemented as a separate service class
        # All tools follow the pattern: Mcp::ToolName.call(**arguments)
        case tool_name
        when "search"
          # Semantic search across the enliterated dataset
          result = ::Mcp::SearchTool.call(**arguments.symbolize_keys)
        when "fetch"
          # Retrieve detailed information about specific items
          result = ::Mcp::FetchTool.call(**arguments.symbolize_keys)
        when "analyze_pools"
          # Real-time entity extraction and analysis
          result = ::Mcp::AnalyzePoolsTool.call(**arguments.symbolize_keys)
        when "pool_bridge"
          # Find connections between concepts or pools
          result = ::Mcp::PoolBridgeTool.call(**arguments.symbolize_keys)
        when "location_neighbors"
          # Spatial relationship analysis for camps
          result = ::Mcp::LocationNeighborsTool.call(**arguments.symbolize_keys)
        when "set_persona"
          # Configure persona-based response styling
          result = ::Mcp::SetPersonaTool.call(**arguments.symbolize_keys)
        when "clear_persona"
          # Remove active persona styling
          result = ::Mcp::ClearPersonaTool.call(**arguments.symbolize_keys)
        else
          # JSON-RPC 2.0 Invalid Params error (-32602) for unknown tools
          return {
            jsonrpc: "2.0",
            error: {
              code: -32602,  # Standard JSON-RPC invalid params code
              message: "Unknown tool: #{tool_name}"
            },
            id: message["id"]
          }
        end

        # Format successful tool result according to MCP protocol
        # MCP requires results to be wrapped in a "content" array with type "text"
        {
          jsonrpc: "2.0",
          result: {
            content: [
              {
                type: "text",  # MCP content type (text, image, etc.)
                text: result.to_json  # Tool result serialized as JSON string
              }
            ]
          },
          id: message["id"]  # Echo back the original request ID
        }
      rescue => e
        # Tool execution error handling with detailed logging
        Rails.logger.error "Tool call error (#{tool_name}): #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n")  # Log stack trace for debugging
        
        # JSON-RPC 2.0 Internal Error response
        {
          jsonrpc: "2.0",
          error: {
            code: -32603,  # Standard JSON-RPC internal error code
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

      # Authentication: Validate API keys for MCP access
      #
      # Supports two authentication methods:
      # 1. Authorization: Bearer <token>
      # 2. X-API-Key: <key>
      #
      # Security considerations:
      # - All requests must be authenticated (MCP is stateless)
      # - Keys should be stored securely (environment variables or database)
      # - Consider rate limiting and key rotation in production
      #
      # See implementation guide: Security Considerations
      def valid_mcp_auth?
        # Extract authentication credentials from headers
        auth_header = request.headers["Authorization"]
        api_key = request.headers["X-API-Key"]

        # TODO: In production, validate against database of API keys with:
        # - User association
        # - Rate limiting
        # - Expiration dates
        # - Scope restrictions
        expected_key = ENV["MCP_API_KEY"] || "burning-man-seven-pools-2025"

        # Check Bearer token format: "Authorization: Bearer <token>"
        if auth_header&.start_with?("Bearer ")
          token = auth_header.split(" ").last
          return token == expected_key
        # Check API key header: "X-API-Key: <key>"
        elsif api_key.present?
          return api_key == expected_key
        end

        # Deny access if no valid authentication provided
        false
      end
      end
    end
  end
end
