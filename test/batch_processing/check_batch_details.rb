#!/usr/bin/env ruby
require_relative 'config/environment'

batch = BatchJob.find_by(batch_id: 'batch_688e0872500c819087aac9aace335662')

puts "Batch Details:"
puts "  Status: #{batch.status}"
puts "  Total items: #{batch.total_items}"
puts "  Completed: #{batch.completed_items}"
puts "  Failed: #{batch.failed_items}"
puts "  Input tokens: #{batch.input_tokens || 'Not recorded'}"
puts "  Output tokens: #{batch.output_tokens || 'Not recorded'}"
puts "  Total cost: #{batch.total_cost || 'Not calculated'}"
puts "  Estimated cost: $#{'%.4f' % batch.estimated_cost}" if batch.estimated_cost

puts "\nMetadata:"
puts JSON.pretty_generate(batch.metadata)

# Check API directly
puts "\n\nChecking API directly..."
client = OpenAI::Client.new(
  api_key: ENV['OPENAI_API_KEY'],
  timeout: 240
)

response = client.batches.retrieve(id: batch.batch_id)
puts "\nAPI Response:"
puts "  Status: #{response['status']}"
puts "  Output file: #{response['output_file_id']}"

if response['usage']
  puts "  Usage data found!"
  puts JSON.pretty_generate(response['usage'])
else
  puts "  No usage data in response"
end