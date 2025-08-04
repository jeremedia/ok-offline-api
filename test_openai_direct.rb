#!/usr/bin/env ruby
require 'bundler/setup'
require 'openai'

puts "Testing OpenAI client directly..."
puts "API Key present: #{!ENV['OPENAI_API_KEY'].nil?}"
puts "=" * 60

begin
  client = OpenAI::Client.new(api_key: ENV['OPENAI_API_KEY'])
  puts "Client created successfully"
  
  # Test embeddings endpoint
  response = client.embeddings.create(
    model: "text-embedding-ada-002",
    input: "2017 temple burning man"
  )
  
  if response
    puts "Response type: #{response.class}"
    # New API returns typed objects
    if response.data && response.data.first
      embedding = response.data.first.embedding
      puts "Success! Generated embedding with #{embedding.length} dimensions"
      puts "First 5 values: #{embedding.first(5).map { |v| v.round(4) }}"
    else
      puts "Response: #{response.inspect}"
    end
  else
    puts "No response received"
  end
rescue => e
  puts "Error: #{e.class} - #{e.message}"
  puts e.backtrace.first(5).join("\n")
end