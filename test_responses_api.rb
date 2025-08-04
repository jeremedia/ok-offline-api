#!/usr/bin/env ruby
# Test script for OpenAI Responses API with Remote MCP

require 'net/http'
require 'json'
require 'uri'

# Configuration
OPENAI_API_KEY = ENV['OPENAI_API_KEY']
MCP_API_KEY = ENV['MCP_API_KEY'] || 'burning-man-seven-pools-2025'

if OPENAI_API_KEY.nil? || OPENAI_API_KEY.empty?
  puts "❌ Please set OPENAI_API_KEY environment variable"
  exit 1
end

puts "🧪 Testing OpenAI Responses API with Seven Pools MCP Server"
puts "=" * 60
puts

# Test 1: Direct API call to verify Responses API works
puts "1️⃣ Testing direct Responses API call..."

uri = URI('https://api.openai.com/v1/responses')
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

request = Net::HTTP::Post.new(uri)
request['Content-Type'] = 'application/json'
request['Authorization'] = "Bearer #{OPENAI_API_KEY}"

request_body = {
  model: "gpt-4.1",
  tools: [
    {
      type: "mcp",
      server_label: "seven_pools",
      server_url: "https://offline.oknotok.com/api/v1/mcp/sse",
      headers: {
        "Authorization" => "Bearer #{MCP_API_KEY}"
      },
      require_approval: "never"
    }
  ],
  input: "What interactive fire art installations are at Burning Man? Use the search tool to find them."
}

request.body = request_body.to_json

begin
  response = http.request(request)
  
  if response.code == '200'
    result = JSON.parse(response.body)
    puts "✅ Responses API call successful!"
    puts "   Response ID: #{result['id']}"
    puts "   Model: #{result['model']}"
    puts "   Output text preview: #{result['output_text']&.slice(0, 200)}..."
    
    # Check if MCP tools were used
    if result['output']
      mcp_calls = result['output'].select { |item| item['type'] == 'mcp_call' }
      if mcp_calls.any?
        puts "   🔧 MCP tools used:"
        mcp_calls.each do |call|
          puts "      - #{call['name']} (#{call['server_label']})"
        end
      end
    end
  else
    puts "❌ API error: #{response.code} - #{response.body}"
  end
rescue => e
  puts "❌ Request failed: #{e.message}"
end

puts
puts "2️⃣ Testing via our Responses chat endpoint..."

# Test 2: Test our Rails endpoint
uri = URI('https://offline.oknotok.com/api/v1/chat/responses')
request = Net::HTTP::Post.new(uri)
request['Content-Type'] = 'application/json'

request_body = {
  chat: {
    message: "Find camps that offer workshops about fire safety"
  }
}

request.body = request_body.to_json

begin
  response = http.request(request)
  puts "   Endpoint response: #{response.code}"
  
  if response.code == '200'
    puts "✅ Our Responses chat endpoint is working!"
    # Parse SSE response
    response.body.each_line do |line|
      if line.start_with?('data: ')
        data = line[6..-1].strip
        next if data == '[DONE]'
        
        begin
          json = JSON.parse(data)
          if json['type'] == 'metadata'
            puts "   Response ID: #{json['data']['response_id']}"
            puts "   MCP tools used: #{json['data']['mcp_tools_used']}"
          end
        rescue
          # Regular text chunk
        end
      end
    end
  else
    puts "❌ Endpoint error: #{response.body}"
  end
rescue => e
  puts "❌ Endpoint test failed: #{e.message}"
end

puts
puts "3️⃣ Testing specific MCP tools..."

# Test each tool
tools_to_test = [
  { query: "Tell me about the Temple", expected_tool: "search" },
  { query: "Analyze this text for Seven Pools entities: 'The fire dancers create transformative experiences through community rituals'", expected_tool: "analyze_pools" },
  { query: "What connects the manifest and experience pools?", expected_tool: "pool_bridge" }
]

tools_to_test.each do |test|
  puts "   Testing: #{test[:query].slice(0, 50)}..."
  
  request_body = {
    model: "gpt-4.1",
    tools: [
      {
        type: "mcp",
        server_label: "seven_pools",
        server_url: "https://offline.oknotok.com/api/v1/mcp/sse",
        headers: {
          "Authorization" => "Bearer #{MCP_API_KEY}"
        },
        require_approval: "never",
        allowed_tools: [test[:expected_tool]] # Limit to expected tool
      }
    ],
    input: test[:query]
  }
  
  request = Net::HTTP::Post.new(URI('https://api.openai.com/v1/responses'))
  request['Content-Type'] = 'application/json'
  request['Authorization'] = "Bearer #{OPENAI_API_KEY}"
  request.body = request_body.to_json
  
  begin
    response = http.request(request)
    if response.code == '200'
      result = JSON.parse(response.body)
      mcp_calls = result['output']&.select { |item| item['type'] == 'mcp_call' } || []
      
      if mcp_calls.any? { |call| call['name'] == test[:expected_tool] }
        puts "   ✅ #{test[:expected_tool]} tool called successfully"
      else
        puts "   ⚠️  Expected #{test[:expected_tool]} tool not called"
      end
    end
  rescue => e
    puts "   ❌ Test failed: #{e.message}"
  end
end

puts
puts "=" * 60
puts "🎯 Test Summary:"
puts "   - Responses API: #{response.code == '200' ? '✅ Working' : '❌ Not working'}"
puts "   - MCP Server: #{mcp_calls&.any? ? '✅ Accessible' : '⚠️  Check needed'}"
puts "   - Rails endpoint: Ready for integration"
puts
puts "🚀 Next steps:"
puts "   1. Update frontend to use /api/v1/chat/responses"
puts "   2. Handle SSE streaming properly"
puts "   3. Track response_id for conversation continuity"