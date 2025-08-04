#!/usr/bin/env ruby
require_relative 'config/environment'

batch_id = 'batch_688e0872500c819087aac9aace335662'

client = OpenAI::Client.new(
  api_key: ENV['OPENAI_API_KEY'],
  timeout: 240
)

response = client.batches.retrieve(id: batch_id)

puts "Raw API Response:"
puts JSON.pretty_generate(response)

# Check if there's usage data
if response['usage']
  puts "\nUsage data found:"
  puts JSON.pretty_generate(response['usage'])
else
  puts "\nNo usage data in response"
end