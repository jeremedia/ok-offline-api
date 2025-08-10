# Rails MCP Server Implementation Guide

## Overview

This guide provides a complete reference for implementing an MCP (Model Context Protocol) server in Ruby on Rails, based on the Seven Pools MCP server implementation. This documentation is designed to enable another Claude Code instance to understand and replicate this architecture in any Rails application.

## What is MCP?

Model Context Protocol (MCP) is a communication protocol that allows AI models to interact with external systems through standardized tool interfaces. It uses JSON-RPC 2.0 over HTTP with Server-Sent Events (SSE) for real-time communication.

Key characteristics:
- **JSON-RPC 2.0**: All messages follow this standard
- **Server-Sent Events**: Real-time streaming communication
- **Tool-based**: Exposes specific capabilities as callable tools
- **Stateless**: Each request is independent
- **Authorization**: API key or Bearer token authentication

## Architecture Overview

```
┌─────────────────┐    HTTP/SSE     ┌─────────────────┐
│   MCP Client    │ ───────────────→│  Rails MCP      │
│   (ChatGPT,     │                 │  Controller     │
│    Claude, etc) │ ←───────────────│  (SSE Endpoint) │
└─────────────────┘                 └─────────────────┘
                                             │
                                             ▼
                                    ┌─────────────────┐
                                    │   Tool Router   │
                                    │  (handle_tool_  │
                                    │      call)      │
                                    └─────────────────┘
                                             │
                        ┌────────────────────┼────────────────────┐
                        ▼                    ▼                    ▼
                ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
                │  Search Tool │    │  Fetch Tool  │    │Analysis Tool │
                │              │    │              │    │              │
                └──────────────┘    └──────────────┘    └──────────────┘
                        │                    │                    │
                        ▼                    ▼                    ▼
                ┌─────────────────────────────────────────────────────┐
                │              Application Services               │
                │        (Search, Database, AI, etc.)            │
                └─────────────────────────────────────────────────────┘
```

## Implementation Components

### 1. MCP Controller (`app/controllers/api/v1/mcp/mcp_controller.rb`)

The controller handles the MCP protocol communication and tool routing. See detailed implementation comments in the file at lines:
- **SSE Setup**: Lines 17-21 (HTTP headers for Server-Sent Events)
- **Request Parsing**: Lines 24-52 (Handle GET/POST requests)
- **Message Routing**: Lines 162-180 (Route to appropriate handlers)
- **Tool Execution**: Lines 182-238 (Execute tools and format responses)
- **Authentication**: Lines 397-414 (API key validation)

Key responsibilities:
- Accept HTTP/SSE connections
- Parse JSON-RPC 2.0 messages
- Route tool calls to appropriate handlers
- Stream responses back to client
- Handle errors gracefully

### 2. Tool Services (`app/services/mcp/`)

Each tool is implemented as a separate service class following a consistent pattern:

```ruby
module Mcp
  class YourTool
    def self.call(**arguments)
      # Validate inputs
      # Process request
      # Return formatted response
    rescue => e
      # Handle errors gracefully
      { error: "Tool failed: #{e.message}" }
    end
  end
end
```

**Current tools** (see `/app/services/mcp/` directory):
- `SearchTool`: Semantic search across datasets
- `FetchTool`: Retrieve detailed item information  
- `AnalyzePoolsTool`: Real-time entity extraction
- `PoolBridgeTool`: Find connections between concepts
- `LocationNeighborsTool`: Spatial relationship analysis
- `SetPersonaTool` / `ClearPersonaTool`: Persona management

### 3. Routes Configuration (`config/routes.rb`)

```ruby
# Lines 44-45 in routes.rb
match 'mcp/sse', to: 'mcp/mcp#sse', via: [:get, :post]
post 'mcp/tools', to: 'mcp/mcp#tools'
```

The SSE endpoint accepts both GET and POST for maximum client compatibility.

## Step-by-Step Implementation

### Step 1: Create the MCP Controller

1. **Create controller structure**:
```bash
mkdir -p app/controllers/api/v1/mcp
touch app/controllers/api/v1/mcp/mcp_controller.rb
```

2. **Implement base controller** (see `mcp_controller.rb:6-88`):
   - Include `ActionController::Live` for SSE support
   - Set proper HTTP headers for streaming
   - Handle request parsing (GET params vs POST body)
   - Implement graceful error handling

3. **Add authentication** (see `mcp_controller.rb:397-414`):
   - Support Bearer tokens and X-API-Key headers
   - Validate against environment variables or database
   - Return 401 for invalid authentication

### Step 2: Implement Protocol Handlers

1. **Initialize handler** (see `mcp_controller.rb:242-286`):
   - Return server capabilities and metadata
   - Support multiple protocol versions
   - Include server information and limits

2. **Tools list handler** (see `mcp_controller.rb:288-395`):
   - Return all available tools with schemas
   - Include detailed input validation schemas
   - Provide clear descriptions for each tool

3. **Tool call handler** (see `mcp_controller.rb:182-238`):
   - Route calls to appropriate tool services
   - Handle argument validation and conversion
   - Format responses according to MCP spec

### Step 3: Create Tool Services

1. **Create tool directory structure**:
```bash
mkdir -p app/services/mcp
```

2. **Implement each tool** following the pattern in `search_tool.rb`:
   - Use class methods for stateless operation
   - Validate all inputs with clear error messages
   - Return consistent response formats
   - Handle exceptions gracefully

3. **Tool structure template**:
```ruby
module Mcp
  class YourTool
    # Constants for validation
    VALID_OPTIONS = %w[option1 option2].freeze
    
    def self.call(required_param:, optional_param: nil)
      # Input validation
      return validation_error("message") unless valid?
      
      # Core logic
      result = process_request(required_param, optional_param)
      
      # Format response
      {
        data: result,
        meta: { timestamp: Time.current.iso8601 }
      }
    rescue => e
      Rails.logger.error "YourTool error: #{e.message}"
      { error: "Processing failed: #{e.message}" }
    end
    
    private
    
    def self.validation_error(message)
      { error: message, data: nil }
    end
  end
end
```

### Step 4: Add Routes and Configuration

1. **Add routes** to `config/routes.rb`:
```ruby
namespace :api do
  namespace :v1 do
    # MCP endpoints
    match 'mcp/sse', to: 'mcp/mcp#sse', via: [:get, :post]
    post 'mcp/tools', to: 'mcp/mcp#tools'  # Optional REST endpoint
  end
end
```

2. **Configure CORS** in `config/initializers/cors.rb`:
```ruby
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*'  # Or specify allowed origins
    resource '/api/v1/mcp/*',
             headers: :any,
             methods: [:get, :post, :options],
             expose: ['Content-Type', 'X-Request-Id']
  end
end
```

3. **Environment variables**:
```bash
# .env
MCP_API_KEY=your-secure-api-key
```

### Step 5: Testing and Validation

1. **Test SSE connection**:
```bash
curl -N -H "X-API-Key: your-api-key" \
     http://localhost:3000/api/v1/mcp/sse
```

2. **Test tool calls**:
```bash
curl -X POST \
     -H "Content-Type: application/json" \
     -H "X-API-Key: your-api-key" \
     -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"your_tool","arguments":{"param":"value"}},"id":1}' \
     http://localhost:3000/api/v1/mcp/sse
```

3. **Integration testing** (create `test/integration/mcp_test.rb`):
```ruby
class McpTest < ActionDispatch::IntegrationTest
  test "mcp sse connection" do
    get "/api/v1/mcp/sse", headers: { "X-API-Key" => "test-key" }
    assert_response :success
    assert_equal "text/event-stream", response.content_type
  end
  
  test "tool call execution" do
    post "/api/v1/mcp/sse", 
         params: {
           jsonrpc: "2.0",
           method: "tools/call",
           params: { name: "your_tool", arguments: { test: "data" } },
           id: 1
         }.to_json,
         headers: { 
           "Content-Type" => "application/json",
           "X-API-Key" => "test-key"
         }
    
    assert_response :success
    response_data = JSON.parse(response.body)
    assert_equal "2.0", response_data["jsonrpc"]
    assert response_data["result"].present?
  end
end
```

## MCP Protocol Specifics

### JSON-RPC 2.0 Message Format

**Request**:
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "tool_name",
    "arguments": { "param": "value" }
  },
  "id": 1
}
```

**Success Response**:
```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [
      { "type": "text", "text": "{\"data\":\"response\"}" }
    ]
  },
  "id": 1
}
```

**Error Response**:
```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32603,
    "message": "Tool execution failed"
  },
  "id": 1
}
```

### Server-Sent Events Format

```
event: message
data: {"jsonrpc":"2.0","result":{"content":[{"type":"text","text":"..."}]},"id":1}

event: error
data: {"jsonrpc":"2.0","error":{"code":-32603,"message":"Error"},"id":1}
```

## Common Gotchas and Solutions

### 1. SSE Buffering Issues

**Problem**: Some proxy servers buffer SSE responses.
**Solution**: Set `X-Accel-Buffering: no` header (see `mcp_controller.rb:20`).

### 2. CORS for Streaming

**Problem**: Browser CORS doesn't work with SSE by default.
**Solution**: Explicitly allow `text/event-stream` content type and set proper origins.

### 3. Connection Management

**Problem**: SSE connections can hang indefinitely.
**Solution**: Always close the stream in an `ensure` block (see `mcp_controller.rb:85-87`).

### 4. JSON Parsing Errors

**Problem**: Malformed JSON crashes the server.
**Solution**: Wrap JSON parsing in try/catch with specific error codes (see `mcp_controller.rb:61-71`).

### 5. Tool State Management

**Problem**: Tools need to maintain state between calls.
**Solution**: Use stateless design with database persistence, not instance variables.

## Security Considerations

1. **Authentication**: Always validate API keys on every request
2. **Input Validation**: Sanitize all tool parameters  
3. **Rate Limiting**: Implement rate limiting for tool calls
4. **Error Information**: Don't expose sensitive data in error messages
5. **CORS**: Be specific about allowed origins in production

## Performance Optimizations

1. **Caching**: Cache frequently accessed data (see `search_entity.rb:36-45`)
2. **Connection Pooling**: Use connection pools for external services
3. **Background Jobs**: Move heavy processing to background jobs
4. **Streaming**: Use SSE for long-running operations
5. **Database Optimization**: Use proper indexing for search operations

## Example Client Usage

```python
import requests
import json

# Connect to MCP server
headers = {"X-API-Key": "your-api-key"}

# Call a tool
payload = {
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
        "name": "search",
        "arguments": {"query": "art installations 2024", "top_k": 10}
    },
    "id": 1
}

response = requests.post(
    "http://localhost:3000/api/v1/mcp/sse",
    headers=headers,
    json=payload,
    stream=True
)

# Parse SSE response
for line in response.iter_lines():
    if line.startswith(b"data: "):
        data = json.loads(line[6:])  # Remove "data: " prefix
        print(data)
```

## Development Workflow

1. **Plan your tools**: Define what capabilities your MCP server will expose
2. **Implement incrementally**: Start with basic search/fetch, add specialized tools
3. **Test thoroughly**: Use both REST endpoint and SSE streaming
4. **Monitor performance**: Log execution times and error rates
5. **Version your protocol**: Support multiple MCP protocol versions

## Advanced Features

### Custom Protocol Extensions

You can extend the base MCP protocol with custom methods:

```ruby
def handle_mcp_message(message)
  case message["method"]
  when "custom/analyze"
    handle_custom_analyze(message)
  # ... standard methods
  end
end
```

### Tool Chaining

Implement tools that call other tools for complex workflows:

```ruby
def self.complex_analysis(query:)
  # Step 1: Search for relevant items
  search_results = SearchTool.call(query: query)
  
  # Step 2: Analyze each result
  analyses = search_results[:items].map do |item|
    AnalyzePoolsTool.call(text: item[:summary])
  end
  
  # Step 3: Synthesize results
  { query: query, results: search_results, analyses: analyses }
end
```

### Real-time Notifications

Use SSE to push updates to connected clients:

```ruby
# In your controller
response.stream.write("event: notification\n")
response.stream.write("data: #{notification.to_json}\n\n")
```

This guide provides everything needed to implement a robust MCP server in Rails. The modular architecture allows for easy extension and customization based on your specific use case.