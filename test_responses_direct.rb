#!/usr/bin/env ruby
# Test direct Responses API streaming with MCP

require 'bundler/setup'
require 'openai'

client = OpenAI::Client.new(api_key: ENV['OPENAI_API_KEY'])

puts "Testing OpenAI Responses API with MCP..."
puts "=" * 60

begin
  stream = client.responses.stream(
    model: "gpt-4.1",
    input: "What fire art is at Burning Man? Use the search tool.",
    tools: [{
      type: "mcp",
      server_label: "seven_pools",
      server_url: "https://offline.oknotok.com/api/v1/mcp/sse",
      headers: {
        "Authorization" => "Bearer #{ENV['MCP_API_KEY'] || 'burning-man-seven-pools-2025'}"
      },
      require_approval: "never"
    }]
  )
  
  puts "Streaming response:"
  
  stream.each do |event|
    case event
    when OpenAI::Streaming::ResponseTextDeltaEvent
      print event.delta
    when OpenAI::Streaming::ResponseToolCallArgumentsDeltaEvent
      puts "\n[MCP Tool: #{event.name}]"
    when OpenAI::Streaming::ResponseCompletedEvent
      puts "\n\nResponse completed! ID: #{event.response.id}"
    when OpenAI::Streaming::ErrorEvent
      puts "\nError: #{event.error}"
    end
  end
  
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(5)
end