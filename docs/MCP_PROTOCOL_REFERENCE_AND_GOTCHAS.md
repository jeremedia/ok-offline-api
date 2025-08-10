# MCP Protocol Reference and Common Gotchas

## Overview

This document provides a complete reference for the Model Context Protocol (MCP) implementation, including common pitfalls, edge cases, and solutions discovered during the development of the Seven Pools MCP server.

## MCP Protocol Specification

### Core Principles

1. **Stateless**: Each request is independent
2. **JSON-RPC 2.0**: All communication uses this standard
3. **Tool-based**: Capabilities exposed as callable tools
4. **Real-time**: Server-Sent Events for streaming responses
5. **Authenticated**: API key or Bearer token required

### Protocol Versions

Current supported versions in order of preference:
- `2025-06-18` (Latest, most stable)
- `2025-03-26` (Older but widely supported)
- `0.1.0` (Legacy, basic compatibility)

**Best Practice**: Always support multiple protocol versions for maximum client compatibility.

## Message Formats

### 1. Initialize Handshake

**Client Request**:
```json
{
  "jsonrpc": "2.0",
  "method": "initialize",
  "params": {
    "protocolVersion": "2025-06-18",
    "capabilities": {
      "roots": { "listChanged": true }
    },
    "clientInfo": {
      "name": "ChatGPT",
      "version": "4.0"
    }
  },
  "id": 1
}
```

**Server Response**:
```json
{
  "jsonrpc": "2.0",
  "result": {
    "protocolVersion": "2025-06-18",
    "capabilities": {
      "tools": {},
      "experimental": {}
    },
    "serverInfo": {
      "name": "Your MCP Server",
      "version": "1.0.0",
      "description": "Server description",
      "dataset": {
        "items": 51391,
        "entities": 461000
      },
      "tools_available": 7,
      "capabilities": ["semantic_search", "entity_extraction"],
      "limits": {
        "max_top_k": 50,
        "max_relation_depth": 3,
        "max_text_length": 8000
      }
    }
  },
  "id": 1
}
```

### 2. Tools List Request

**Client Request**:
```json
{
  "jsonrpc": "2.0",
  "method": "tools/list",
  "params": {},
  "id": 2
}
```

**Server Response**:
```json
{
  "jsonrpc": "2.0",
  "result": {
    "tools": [
      {
        "name": "search",
        "description": "Semantic search across dataset",
        "inputSchema": {
          "type": "object",
          "properties": {
            "query": {
              "type": "string",
              "description": "Natural language search query"
            },
            "limit": {
              "type": "integer",
              "description": "Maximum results (1-50)",
              "minimum": 1,
              "maximum": 50,
              "default": 10
            }
          },
          "required": ["query"]
        }
      }
    ]
  },
  "id": 2
}
```

### 3. Tool Call

**Client Request**:
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "search",
    "arguments": {
      "query": "art installations 2024",
      "limit": 10
    }
  },
  "id": 3
}
```

**Server Response**:
```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [
      {
        "type": "text",
        "text": "{\"results\":[...],\"meta\":{\"total\":42}}"
      }
    ]
  },
  "id": 3
}
```

## Server-Sent Events (SSE) Implementation

### Required Headers

```http
Content-Type: text/event-stream
Cache-Control: no-cache
Connection: keep-alive
X-Accel-Buffering: no
Access-Control-Allow-Origin: *
```

### SSE Message Format

```
event: message
data: {"jsonrpc":"2.0","result":{"content":[{"type":"text","text":"..."}]},"id":1}

event: error
data: {"jsonrpc":"2.0","error":{"code":-32603,"message":"Error"},"id":1}

event: notification
data: {"type":"status","message":"Processing..."}

```

**Critical**: Always end SSE messages with double newline (`\n\n`).

### Connection Lifecycle

1. **Establishment**: Client connects to SSE endpoint
2. **Authentication**: Validate on first message
3. **Heartbeat**: Empty requests for keepalive
4. **Processing**: Handle JSON-RPC messages
5. **Termination**: Always close stream in `ensure` block

## JSON-RPC 2.0 Error Codes

### Standard Codes

| Code | Name | Description |
|------|------|-------------|
| -32700 | Parse error | Invalid JSON was received |
| -32600 | Invalid Request | The JSON sent is not a valid Request object |
| -32601 | Method not found | The method does not exist |
| -32602 | Invalid params | Invalid method parameter(s) |
| -32603 | Internal error | Internal JSON-RPC error |

### Custom Application Codes

| Code | Name | Use Case |
|------|------|----------|
| -32000 | Server error | Generic server-side error |
| -32001 | Authentication failed | Invalid API key or token |
| -32002 | Rate limit exceeded | Too many requests |
| -32003 | Resource not found | Requested resource doesn't exist |
| -32004 | Validation error | Input validation failed |

## Common Gotchas and Solutions

### 1. SSE Connection Management

#### Problem: Connections hang indefinitely

**Symptoms**:
- Client connections never terminate
- Server memory usage grows
- Connection pool exhaustion

**Root Cause**: Not closing SSE stream properly

**Solution**:
```ruby
begin
  # ... process request
ensure
  response.stream.close  # CRITICAL: Always close in ensure block
end
```

**Prevention**:
- Use `ensure` blocks for all SSE endpoints
- Monitor connection counts in production
- Set connection timeouts

### 2. JSON Parsing Edge Cases

#### Problem: Malformed JSON crashes server

**Symptoms**:
- Server returns 500 errors
- No proper error response to client
- Logs show JSON parse exceptions

**Root Cause**: Not handling `JSON::ParserError`

**Solution**:
```ruby
begin
  message = JSON.parse(request_body)
rescue JSON::ParserError => e
  error_response = {
    jsonrpc: "2.0",
    error: {
      code: -32700,  # Standard parse error code
      message: "Parse error: #{e.message}"
    },
    id: nil  # Cannot determine ID from malformed request
  }
  response.stream.write("event: error\\n")
  response.stream.write("data: #{error_response.to_json}\\n\\n")
  return
end
```

### 3. CORS for Server-Sent Events

#### Problem: Browser blocks SSE connections

**Symptoms**:
- CORS errors in browser console
- SSE connection fails to establish
- Preflight OPTIONS requests fail

**Root Cause**: SSE requires specific CORS configuration

**Solution**:
```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*'  # Or specific domains in production
    resource '/api/v1/mcp/*',
             headers: :any,
             methods: [:get, :post, :options],
             expose: ['Content-Type', 'X-Request-Id', 'Cache-Control'],
             credentials: false  # Set to true if using cookies
  end
end
```

### 4. Nginx/Proxy Buffering

#### Problem: SSE responses are buffered by proxy

**Symptoms**:
- Delayed responses
- Batched messages instead of real-time
- Client timeout errors

**Root Cause**: Proxy servers buffer SSE by default

**Solution**:
```ruby
# In your controller
response.headers["X-Accel-Buffering"] = "no"  # Nginx
response.headers["X-Proxy-Buffering"] = "no"  # Other proxies
```

**Nginx Configuration**:
```nginx
location /api/v1/mcp/ {
    proxy_pass http://your_rails_app;
    proxy_buffering off;
    proxy_cache off;
    proxy_set_header Connection '';
    proxy_http_version 1.1;
    chunked_transfer_encoding off;
}
```

### 5. Authentication State Management

#### Problem: Session-based auth doesn't work with MCP

**Symptoms**:
- Authentication randomly fails
- Client can't maintain session
- CSRF token errors

**Root Cause**: MCP is stateless, each request is independent

**Solution**: Use stateless authentication only
```ruby
def valid_mcp_auth?
  # DON'T use sessions or CSRF tokens
  # DO use API keys or JWT tokens
  api_key = request.headers["X-API-Key"]
  expected_key = ENV["MCP_API_KEY"]
  api_key == expected_key
end
```

### 6. Request Method Handling

#### Problem: Some clients send GET, others send POST

**Symptoms**:
- Inconsistent request handling
- Parameters sometimes missing
- Method not allowed errors

**Root Cause**: MCP clients vary in HTTP method preference

**Solution**: Support both methods
```ruby
# In routes.rb
match 'mcp/sse', to: 'mcp/mcp#sse', via: [:get, :post]

# In controller
def sse
  if request.get?
    # GET: parameters in URL
    message = {
      "jsonrpc" => params[:jsonrpc],
      "method" => params[:method],
      "id" => params[:id],
      "params" => params[:params] || {}
    }
  else
    # POST: JSON in body
    request_body = request.body.read
    message = JSON.parse(request_body) unless request_body.blank?
  end
  
  # Handle empty requests (connection establishment)
  return send_heartbeat if message.nil?
  
  # Process message...
end
```

### 7. Tool Response Format

#### Problem: Client can't parse tool responses

**Symptoms**:
- Tools appear to execute but return no data
- Client shows formatting errors
- JSON parsing errors on client side

**Root Cause**: MCP requires specific response wrapping

**Solution**: Always wrap tool results in content array
```ruby
# WRONG: Direct JSON response
{
  jsonrpc: "2.0",
  result: { data: "result" },
  id: message["id"]
}

# CORRECT: MCP-compliant format
{
  jsonrpc: "2.0",
  result: {
    content: [
      {
        type: "text",
        text: { data: "result" }.to_json  # Tool result as JSON string
      }
    ]
  },
  id: message["id"]
}
```

### 8. Large Response Handling

#### Problem: Large responses break SSE streaming

**Symptoms**:
- Connection timeouts with large datasets
- Memory usage spikes
- Client receives partial responses

**Root Cause**: Single large SSE message exceeds limits

**Solution**: Stream large responses in chunks
```ruby
def stream_large_response(large_data, message_id)
  chunk_size = 1000  # Adjust based on your data
  
  large_data.each_slice(chunk_size).with_index do |chunk, index|
    partial_response = {
      jsonrpc: "2.0",
      result: {
        content: [
          {
            type: "text",
            text: {
              chunk_index: index,
              chunk_data: chunk,
              is_final: index == (large_data.size / chunk_size).ceil - 1
            }.to_json
          }
        ]
      },
      id: message_id
    }
    
    response.stream.write("event: message\\n")
    response.stream.write("data: #{partial_response.to_json}\\n\\n")
  end
end
```

### 9. Error Context Loss

#### Problem: Tool errors don't preserve request context

**Symptoms**:
- Generic error messages
- Difficult debugging
- Lost request traceability

**Root Cause**: Exception handling strips context

**Solution**: Preserve context in error responses
```ruby
def handle_tool_call(message)
  params = message["params"] || {}
  tool_name = params["name"]
  arguments = params["arguments"] || {}
  
  # Log context BEFORE execution
  Rails.logger.info "Tool call: #{tool_name} with args: #{arguments.inspect} (id: #{message['id']})"
  
  result = execute_tool(tool_name, arguments)
  
  # Success response with context
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
  # Preserve full context in error
  Rails.logger.error "Tool call error - Tool: #{tool_name}, Args: #{arguments.inspect}, Error: #{e.message}"
  Rails.logger.error "Stack trace: #{e.backtrace.first(10).join('\\n')}"
  
  {
    jsonrpc: "2.0",
    error: {
      code: -32603,
      message: "Tool '#{tool_name}' failed: #{e.message}",
      data: {
        tool_name: tool_name,
        arguments: arguments,
        error_class: e.class.name
      }
    },
    id: message["id"]
  }
end
```

### 10. Protocol Version Negotiation

#### Problem: Clients request unsupported protocol versions

**Symptoms**:
- Initialization fails
- Feature compatibility issues
- Client falls back to basic functionality

**Root Cause**: Not handling version negotiation properly

**Solution**: Support multiple versions gracefully
```ruby
def handle_initialize_request(message)
  client_version = message.dig("params", "protocolVersion")
  supported_versions = ["2025-06-18", "2025-03-26", "0.1.0"]
  
  # Use client's version if supported, otherwise use latest
  protocol_version = if supported_versions.include?(client_version)
                      client_version
                     else
                       supported_versions.first  # Latest version
                     end
  
  # Adjust capabilities based on protocol version
  capabilities = case protocol_version
                 when "0.1.0"
                   { tools: true }  # Legacy format
                 else
                   { tools: {}, experimental: {} }  # Modern format
                 end
  
  {
    jsonrpc: "2.0",
    result: {
      protocolVersion: protocol_version,
      capabilities: capabilities,
      serverInfo: {
        name: "Your MCP Server",
        version: "1.0.0",
        protocols: supported_versions  # Advertise all supported versions
      }
    },
    id: message["id"]
  }
end
```

## Performance Optimization

### 1. Connection Pooling

```ruby
# config/database.yml
production:
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 25 } %>
  checkout_timeout: 5
```

### 2. Caching Strategies

```ruby
# Cache expensive operations
def get_tool_results(query)
  cache_key = "mcp_tool_#{Digest::SHA256.hexdigest(query)}"
  Rails.cache.fetch(cache_key, expires_in: 1.hour) do
    expensive_operation(query)
  end
end
```

### 3. Background Processing

```ruby
# For long-running operations
def handle_expensive_tool_call(message)
  job_id = SecureRandom.uuid
  
  # Start background job
  ExpensiveToolJob.perform_async(job_id, message["params"])
  
  # Return immediate response with job ID
  {
    jsonrpc: "2.0",
    result: {
      content: [
        {
          type: "text",
          text: {
            status: "processing",
            job_id: job_id,
            estimated_completion: 30.seconds.from_now
          }.to_json
        }
      ]
    },
    id: message["id"]
  }
end
```

## Security Best Practices

### 1. Input Validation

```ruby
def validate_tool_arguments(tool_name, arguments)
  case tool_name
  when "search"
    raise ArgumentError, "Query too long" if arguments[:query].length > 1000
    raise ArgumentError, "Invalid limit" unless (1..50).cover?(arguments[:limit])
  end
end
```

### 2. Rate Limiting

```ruby
# Using rack-attack
Rack::Attack.throttle('mcp/tool', limit: 100, period: 1.hour) do |req|
  req.ip if req.path.start_with?('/api/v1/mcp/') && req.post?
end
```

### 3. API Key Management

```ruby
# Store API keys in database with metadata
class ApiKey < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
  
  scope :active, -> { where(revoked_at: nil) }
  
  def revoke!
    update!(revoked_at: Time.current)
  end
  
  def rate_limit_key
    "mcp_rate_limit_#{id}"
  end
end
```

## Monitoring and Observability

### 1. Metrics Collection

```ruby
# Track MCP usage
class McpMetrics
  def self.track_tool_call(tool_name, execution_time, success)
    Rails.logger.info({
      event: "mcp_tool_call",
      tool: tool_name,
      duration: execution_time,
      success: success,
      timestamp: Time.current.iso8601
    }.to_json)
  end
end
```

### 2. Health Checks

```ruby
# Add health check endpoint
def health
  {
    status: "ok",
    version: "1.0.0",
    connections: active_connections_count,
    uptime: uptime_seconds
  }
rescue => e
  {
    status: "error",
    error: e.message
  }
end
```

This comprehensive reference should help you avoid the most common pitfalls when implementing MCP servers in Rails. Always test thoroughly with multiple client types to ensure compatibility.