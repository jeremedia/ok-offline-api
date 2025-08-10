# MCP Server Step-by-Step Implementation Guide

## Overview

This guide provides exact steps to implement an MCP (Model Context Protocol) server in Rails. Follow these steps sequentially to create a working MCP server that can be used by ChatGPT, Claude, or custom applications.

**Time estimate**: 2-4 hours for basic implementation
**Prerequisites**: Rails application with PostgreSQL database

## Step 1: Project Setup (15 minutes)

### 1.1 Add Required Dependencies

Add to your `Gemfile`:

```ruby
# For Server-Sent Events support
gem 'actioncable'

# For CORS handling (if not already present)
gem 'rack-cors'

# For JSON schema validation (optional but recommended)
gem 'json-schema'
```

Run:
```bash
bundle install
```

### 1.2 Create Directory Structure

```bash
mkdir -p app/controllers/api/v1/mcp
mkdir -p app/services/mcp
mkdir -p test/integration
```

### 1.3 Set Environment Variables

Add to your `.env` file:
```bash
MCP_API_KEY=your-secure-random-key-here
# Generate with: SecureRandom.hex(32)
```

## Step 2: Configure CORS (10 minutes)

### 2.1 Create or Update CORS Initializer

Create `config/initializers/cors.rb`:

```ruby
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*'  # In production, specify allowed domains
    resource '/api/v1/mcp/*',
             headers: :any,
             methods: [:get, :post, :options],
             expose: ['Content-Type', 'X-Request-Id']
  end
end
```

### 2.2 Add Routes

Add to `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # MCP endpoints
      match 'mcp/sse', to: 'mcp/mcp#sse', via: [:get, :post]
      post 'mcp/tools', to: 'mcp/mcp#tools'  # Optional REST endpoint for testing
    end
  end
  
  # ... your other routes
end
```

## Step 3: Create the MCP Controller (30 minutes)

### 3.1 Create Base Controller

Create `app/controllers/api/v1/mcp/mcp_controller.rb`:

```ruby
# frozen_string_literal: true

module Api
  module V1
    module Mcp
      class McpController < ApplicationController
        include ActionController::Live

        # Main SSE endpoint for MCP communication
        def sse
          # Authentication
          unless valid_mcp_auth?
            render json: { error: "Unauthorized" }, status: :unauthorized
            return
          end

          # Configure SSE headers
          response.headers["Content-Type"] = "text/event-stream"
          response.headers["Cache-Control"] = "no-cache"
          response.headers["Connection"] = "keep-alive"
          response.headers["X-Accel-Buffering"] = "no"
          response.headers["Access-Control-Allow-Origin"] = "*"

          begin
            # Parse request
            if request.get?
              if params[:jsonrpc].present?
                message = {
                  "jsonrpc" => params[:jsonrpc],
                  "method" => params[:method],
                  "id" => params[:id],
                  "params" => params[:params] || {}
                }
              else
                response.stream.write(": MCP Server Ready\\n\\n")
                response.stream.close
                return
              end
            else
              request_body = request.body.read
              if request_body.blank?
                response.stream.write(": MCP Server Ready\\n\\n")
                response.stream.close
                return
              end
              message = JSON.parse(request_body)
            end

            # Process message
            result = handle_mcp_message(message)

            # Stream response
            response.stream.write("event: message\\n")
            response.stream.write("data: #{result.to_json}\\n\\n")

          rescue JSON::ParserError => e
            error_response = {
              jsonrpc: "2.0",
              error: { code: -32700, message: "Parse error: #{e.message}" },
              id: nil
            }
            response.stream.write("event: error\\n")
            response.stream.write("data: #{error_response.to_json}\\n\\n")
          rescue => e
            Rails.logger.error "MCP SSE error: #{e.message}"
            error_response = {
              jsonrpc: "2.0",
              error: { code: -32603, message: "Internal error: #{e.message}" },
              id: message&.dig("id")
            }
            response.stream.write("event: error\\n")
            response.stream.write("data: #{error_response.to_json}\\n\\n")
          ensure
            response.stream.close
          end
        end

        # Optional REST endpoint for testing
        def tools
          message = JSON.parse(request.body.read)
          result = handle_mcp_message(message)
          render json: result
        rescue => e
          render json: { error: "Server error: #{e.message}" }, status: :internal_server_error
        end

        private

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
              error: { code: -32601, message: "Method not found: #{message['method']}" },
              id: message["id"]
            }
          end
        end

        def handle_initialize_request(message)
          {
            jsonrpc: "2.0",
            result: {
              protocolVersion: "2025-06-18",
              capabilities: { tools: {}, experimental: {} },
              serverInfo: {
                name: "Your MCP Server",
                version: "1.0.0",
                description: "Rails MCP Server Implementation"
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
                  name: "hello",
                  description: "Simple greeting tool",
                  inputSchema: {
                    type: "object",
                    properties: {
                      name: { type: "string", description: "Name to greet" }
                    },
                    required: ["name"]
                  }
                }
                # Add more tools here
              ]
            },
            id: message["id"]
          }
        end

        def handle_tool_call(message)
          params = message["params"] || {}
          tool_name = params["name"]
          arguments = params["arguments"] || {}

          case tool_name
          when "hello"
            result = { greeting: "Hello, #{arguments['name']}!" }
          else
            return {
              jsonrpc: "2.0",
              error: { code: -32602, message: "Unknown tool: #{tool_name}" },
              id: message["id"]
            }
          end

          {
            jsonrpc: "2.0",
            result: {
              content: [{ type: "text", text: result.to_json }]
            },
            id: message["id"]
          }
        rescue => e
          Rails.logger.error "Tool call error: #{e.message}"
          {
            jsonrpc: "2.0",
            error: { code: -32603, message: "Tool execution failed: #{e.message}" },
            id: message["id"]
          }
        end

        def valid_mcp_auth?
          auth_header = request.headers["Authorization"]
          api_key = request.headers["X-API-Key"]
          expected_key = ENV["MCP_API_KEY"]

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
```

## Step 4: Test Basic Functionality (15 minutes)

### 4.1 Start Rails Server

```bash
rails server -b 0.0.0.0 -p 3000
```

### 4.2 Test SSE Connection

```bash
curl -N -H "X-API-Key: your-secure-random-key-here" \\
     http://localhost:3000/api/v1/mcp/sse
```

Expected response:
```
: MCP Server Ready
```

### 4.3 Test Initialize

```bash
curl -X POST \\
     -H "Content-Type: application/json" \\
     -H "X-API-Key: your-secure-random-key-here" \\
     -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-06-18"},"id":1}' \\
     http://localhost:3000/api/v1/mcp/sse
```

### 4.4 Test Tools List

```bash
curl -X POST \\
     -H "Content-Type: application/json" \\
     -H "X-API-Key: your-secure-random-key-here" \\
     -d '{"jsonrpc":"2.0","method":"tools/list","id":2}' \\
     http://localhost:3000/api/v1/mcp/sse
```

### 4.5 Test Tool Call

```bash
curl -X POST \\
     -H "Content-Type: application/json" \\
     -H "X-API-Key: your-secure-random-key-here" \\
     -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"hello","arguments":{"name":"World"}},"id":3}' \\
     http://localhost:3000/api/v1/mcp/sse
```

## Step 5: Create Your First Custom Tool (20 minutes)

### 5.1 Create Tool Service

Create `app/services/mcp/search_tool.rb`:

```ruby
module Mcp
  class SearchTool
    def self.call(query:, limit: 10)
      # Replace this with your actual search logic
      # For example, searching a User model:
      results = User.where("name ILIKE ?", "%#{query}%").limit(limit)
      
      formatted_results = results.map do |user|
        {
          id: user.id,
          name: user.name,
          email: user.email
        }
      end

      {
        query: query,
        results: formatted_results,
        total: results.count
      }
    rescue => e
      Rails.logger.error "SearchTool error: #{e.message}"
      { error: "Search failed: #{e.message}", results: [] }
    end
  end
end
```

### 5.2 Update Controller to Include New Tool

In your `mcp_controller.rb`, update the `handle_tools_list_request` method:

```ruby
def handle_tools_list_request(message)
  {
    jsonrpc: "2.0",
    result: {
      tools: [
        {
          name: "hello",
          description: "Simple greeting tool",
          inputSchema: {
            type: "object",
            properties: {
              name: { type: "string", description: "Name to greet" }
            },
            required: ["name"]
          }
        },
        {
          name: "search",
          description: "Search for users by name",
          inputSchema: {
            type: "object",
            properties: {
              query: { type: "string", description: "Search query" },
              limit: { type: "integer", description: "Max results (default 10)" }
            },
            required: ["query"]
          }
        }
      ]
    },
    id: message["id"]
  }
end
```

Update the `handle_tool_call` method:

```ruby
def handle_tool_call(message)
  params = message["params"] || {}
  tool_name = params["name"]
  arguments = params["arguments"] || {}

  case tool_name
  when "hello"
    result = { greeting: "Hello, #{arguments['name']}!" }
  when "search"
    result = ::Mcp::SearchTool.call(**arguments.symbolize_keys)
  else
    return {
      jsonrpc: "2.0",
      error: { code: -32602, message: "Unknown tool: #{tool_name}" },
      id: message["id"]
    }
  end

  {
    jsonrpc: "2.0",
    result: {
      content: [{ type: "text", text: result.to_json }]
    },
    id: message["id"]
  }
rescue => e
  Rails.logger.error "Tool call error: #{e.message}"
  {
    jsonrpc: "2.0",
    error: { code: -32603, message: "Tool execution failed: #{e.message}" },
    id: message["id"]
  }
end
```

### 5.3 Test New Tool

```bash
curl -X POST \\
     -H "Content-Type: application/json" \\
     -H "X-API-Key: your-secure-random-key-here" \\
     -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"search","arguments":{"query":"john","limit":5}},"id":4}' \\
     http://localhost:3000/api/v1/mcp/sse
```

## Step 6: Add Error Handling and Logging (15 minutes)

### 6.1 Create Logging Initializer

Create `config/initializers/mcp_logging.rb`:

```ruby
# MCP-specific logging configuration
Rails.application.configure do
  if Rails.env.development?
    config.log_level = :info
  end
end

# Log MCP requests to separate file in production
if Rails.env.production?
  mcp_logger = Logger.new(Rails.root.join('log', 'mcp.log'))
  mcp_logger.formatter = proc do |severity, datetime, progname, msg|
    "[#{datetime}] #{severity}: #{msg}\\n"
  end
  
  Rails.application.config.mcp_logger = mcp_logger
end
```

### 6.2 Add Request/Response Logging

Update your controller to log requests:

```ruby
def handle_mcp_message(message)
  Rails.logger.info "MCP Request: #{message['method']} (id: #{message['id']})"
  
  result = case message["method"]
           when "tools/call"
             handle_tool_call(message)
           when "tools/list"
             handle_tools_list_request(message)
           when "initialize"
             handle_initialize_request(message)
           else
             {
               jsonrpc: "2.0",
               error: { code: -32601, message: "Method not found: #{message['method']}" },
               id: message["id"]
             }
           end
           
  Rails.logger.info "MCP Response: #{result[:error] ? 'ERROR' : 'SUCCESS'} (id: #{message['id']})"
  result
end
```

## Step 7: Add Integration Tests (20 minutes)

### 7.1 Create Test File

Create `test/integration/mcp_test.rb`:

```ruby
require 'test_helper'

class McpTest < ActionDispatch::IntegrationTest
  def setup
    @api_key = ENV["MCP_API_KEY"] || "test-key"
    @headers = { "X-API-Key" => @api_key }
  end

  test "sse connection establishment" do
    get "/api/v1/mcp/sse", headers: @headers
    assert_response :success
    assert_equal "text/event-stream", response.content_type
  end

  test "initialize handshake" do
    post "/api/v1/mcp/sse", 
         params: {
           jsonrpc: "2.0",
           method: "initialize",
           params: { protocolVersion: "2025-06-18" },
           id: 1
         }.to_json,
         headers: @headers.merge({ "Content-Type" => "application/json" })
         
    assert_response :success
    response_lines = response.body.split("\\n")
    data_line = response_lines.find { |line| line.start_with?("data: ") }
    assert data_line.present?
    
    data = JSON.parse(data_line.sub("data: ", ""))
    assert_equal "2.0", data["jsonrpc"]
    assert data["result"]["serverInfo"].present?
  end

  test "tools list request" do
    post "/api/v1/mcp/sse",
         params: {
           jsonrpc: "2.0",
           method: "tools/list",
           id: 2
         }.to_json,
         headers: @headers.merge({ "Content-Type" => "application/json" })

    assert_response :success
    response_lines = response.body.split("\\n")
    data_line = response_lines.find { |line| line.start_with?("data: ") }
    
    data = JSON.parse(data_line.sub("data: ", ""))
    assert data["result"]["tools"].present?
    assert data["result"]["tools"].is_a?(Array)
  end

  test "hello tool call" do
    post "/api/v1/mcp/sse",
         params: {
           jsonrpc: "2.0",
           method: "tools/call",
           params: {
             name: "hello",
             arguments: { name: "Test" }
           },
           id: 3
         }.to_json,
         headers: @headers.merge({ "Content-Type" => "application/json" })

    assert_response :success
    response_lines = response.body.split("\\n")
    data_line = response_lines.find { |line| line.start_with?("data: ") }
    
    data = JSON.parse(data_line.sub("data: ", ""))
    assert data["result"]["content"].present?
    content_text = JSON.parse(data["result"]["content"][0]["text"])
    assert_equal "Hello, Test!", content_text["greeting"]
  end

  test "unauthorized access" do
    get "/api/v1/mcp/sse", headers: { "X-API-Key" => "invalid" }
    assert_response :unauthorized
  end
end
```

### 7.2 Run Tests

```bash
rails test test/integration/mcp_test.rb
```

## Step 8: Production Deployment Checklist (10 minutes)

### 8.1 Security Configuration

1. **Update CORS origins**:
```ruby
# config/initializers/cors.rb
origins ['https://yourdomain.com', 'https://chat.openai.com']  # Specific domains only
```

2. **Secure API keys**:
```bash
# Use strong, unique API keys
MCP_API_KEY=$(openssl rand -hex 32)
```

3. **Add rate limiting** (consider using `rack-attack` gem):
```ruby
# config/initializers/rack_attack.rb
Rack::Attack.throttle('mcp/ip', limit: 100, period: 1.hour) do |req|
  req.ip if req.path.start_with?('/api/v1/mcp/')
end
```

### 8.2 Performance Configuration

1. **Configure production logging**:
```ruby
# config/environments/production.rb
config.log_level = :info
config.lograge.enabled = true
```

2. **Add database connection pooling**:
```ruby
# config/database.yml
production:
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 25 } %>
```

3. **Configure web server for SSE** (Puma example):
```ruby
# config/puma.rb
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
threads threads_count, threads_count
workers ENV.fetch("WEB_CONCURRENCY") { 2 }
```

## Step 9: Advanced Features (Optional)

### 9.1 Tool Chaining

Create tools that call other tools:

```ruby
module Mcp
  class AnalysisTool
    def self.call(query:)
      # Step 1: Search for data
      search_results = SearchTool.call(query: query, limit: 5)
      
      # Step 2: Process each result
      analyses = search_results[:results].map do |item|
        # Your analysis logic here
        { item: item, analysis: "Analyzed: #{item[:name]}" }
      end
      
      { query: query, analyses: analyses }
    end
  end
end
```

### 9.2 Real-time Notifications

Use SSE to push updates:

```ruby
# In your controller
def push_notification(notification)
  response.stream.write("event: notification\\n")
  response.stream.write("data: #{notification.to_json}\\n\\n")
end
```

### 9.3 Custom Protocol Extensions

Add custom methods beyond the standard MCP protocol:

```ruby
def handle_mcp_message(message)
  case message["method"]
  when "custom/analyze"
    handle_custom_analyze(message)
  # ... standard methods
  else
    # Handle unknown methods
  end
end
```

## Troubleshooting Common Issues

### Connection Issues
- **Symptom**: SSE connection drops immediately
- **Solution**: Check CORS configuration and API key validation

### Buffering Problems
- **Symptom**: Responses delayed or batched
- **Solution**: Ensure `X-Accel-Buffering: no` header is set

### JSON Parsing Errors
- **Symptom**: Parse errors with valid JSON
- **Solution**: Check content-type headers and request body encoding

### Memory Leaks
- **Symptom**: Server memory usage grows over time
- **Solution**: Always close SSE streams in `ensure` blocks

## Next Steps

1. **Implement domain-specific tools** based on your application's data
2. **Add comprehensive error handling** and logging
3. **Create client libraries** for easier integration
4. **Monitor performance** and optimize bottlenecks
5. **Add automated testing** for all tools and edge cases

Your MCP server is now ready for integration with AI clients! 

For more advanced implementations, study the complete Seven Pools MCP server in this codebase (`app/controllers/api/v1/mcp/` and `app/services/mcp/`).