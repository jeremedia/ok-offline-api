#!/usr/bin/env ruby
# Demonstrate the power of stateless conversations with Responses API

require 'net/http'
require 'json'
require 'uri'

OPENAI_API_KEY = ENV['OPENAI_API_KEY']
MCP_API_KEY = ENV['MCP_API_KEY'] || 'burning-man-seven-pools-2025'

if OPENAI_API_KEY.nil?
  puts "❌ Please set OPENAI_API_KEY"
  exit 1
end

puts "🌊 Testing Stateless Conversations with Seven Pools MCP"
puts "=" * 60
puts

# First message - no previous_response_id
puts "1️⃣ First message (with system instructions)..."

uri = URI('https://api.openai.com/v1/responses')
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true

request1 = Net::HTTP::Post.new(uri)
request1['Content-Type'] = 'application/json'
request1['Authorization'] = "Bearer #{OPENAI_API_KEY}"

request1.body = {
  model: "gpt-4.1",
  instructions: "You are a Burning Man expert with access to the Seven Pools MCP server.",
  tools: [{
    type: "mcp",
    server_label: "seven_pools",
    server_url: "https://offline.oknotok.com/api/v1/mcp/sse",
    headers: { "Authorization" => "Bearer #{MCP_API_KEY}" },
    require_approval: "never"
  }],
  input: "What camps offer fire performances?",
  store: true # Critical for conversation continuity!
}.to_json

response1 = http.request(request1)
result1 = JSON.parse(response1.body)

puts "✅ Response ID: #{result1['id']}"
puts "   Output: #{result1['output_text']&.slice(0, 200)}..."

# Extract tools used
mcp_calls = result1['output']&.select { |item| item['type'] == 'mcp_call' } || []
puts "   Tools used: #{mcp_calls.map { |c| c['name'] }.join(', ')}"

puts
puts "2️⃣ Second message (using previous_response_id - NO HISTORY NEEDED!)..."

# Second message - just previous_response_id and new input!
request2 = Net::HTTP::Post.new(uri)
request2['Content-Type'] = 'application/json'
request2['Authorization'] = "Bearer #{OPENAI_API_KEY}"

request2.body = {
  model: "gpt-4.1",
  previous_response_id: result1['id'], # The magic! 
  input: "Which of those camps are near Center Camp?",
  tools: [{
    type: "mcp",
    server_label: "seven_pools", 
    server_url: "https://offline.oknotok.com/api/v1/mcp/sse",
    headers: { "Authorization" => "Bearer #{MCP_API_KEY}" },
    require_approval: "never"
  }],
  store: true
}.to_json

response2 = http.request(request2)
result2 = JSON.parse(response2.body)

puts "✅ Response ID: #{result2['id']}"
puts "   Output: #{result2['output_text']&.slice(0, 200)}..."
puts "   The AI remembers the context without us sending any history!"

puts
puts "3️⃣ Third message (continuing the conversation)..."

request3 = Net::HTTP::Post.new(uri)
request3['Content-Type'] = 'application/json'
request3['Authorization'] = "Bearer #{OPENAI_API_KEY}"

request3.body = {
  model: "gpt-4.1",
  previous_response_id: result2['id'],
  input: "Analyze the concept of fire performance for Seven Pools entities",
  tools: [{
    type: "mcp",
    server_label: "seven_pools",
    server_url: "https://offline.oknotok.com/api/v1/mcp/sse",
    headers: { "Authorization" => "Bearer #{MCP_API_KEY}" },
    require_approval: "never"
  }],
  store: true
}.to_json

response3 = http.request(request3)
result3 = JSON.parse(response3.body)

puts "✅ Response ID: #{result3['id']}"
puts "   Output: #{result3['output_text']&.slice(0, 200)}..."

# Check if analyze_pools was used
mcp_calls3 = result3['output']&.select { |item| item['type'] == 'mcp_call' } || []
if mcp_calls3.any? { |c| c['name'] == 'analyze_pools' }
  puts "   ✅ Used analyze_pools tool as expected!"
end

puts
puts "=" * 60
puts "🎯 Key Insights:"
puts "   - NO conversation history management needed"
puts "   - Each request only needs previous_response_id"
puts "   - OpenAI handles all context automatically"
puts "   - Perfect for stateless, scalable applications"
puts "   - Works seamlessly with MCP tools"
puts
puts "💡 This is why Responses API > Chat Completions API for production!"