#!/usr/bin/env ruby
require_relative 'config/environment'

batch_id = 'batch_688e1366e2848190b2f5fa1a87c86b28'

client = OpenAI::Client.new(
  api_key: ENV['OPENAI_API_KEY'],
  timeout: 240
)

puts "🔍 Debugging Single-Item Batch"
puts "=" * 60

# Get full API response
response = client.batches.retrieve(id: batch_id)

puts "\nAPI Response:"
puts JSON.pretty_generate(response)

# Check our database record
batch_job = BatchJob.find_by(batch_id: batch_id)
if batch_job
  puts "\n\nDatabase Record:"
  puts "  Status: #{batch_job.status}"
  puts "  Total items: #{batch_job.total_items}"
  puts "  Completed: #{batch_job.completed_items}"
  puts "  Item IDs: #{batch_job.metadata['item_ids']}"
  
  # Get the item
  if item_id = batch_job.metadata['item_ids']&.first
    item = SearchableItem.find(item_id)
    puts "\n📄 Item Details:"
    puts "  Name: #{item.name}"
    puts "  Type: #{item.item_type}"
    puts "  Description length: #{item.description&.length || 0} chars"
    puts "  Searchable text length: #{item.searchable_text&.length || 0} chars"
  end
end

# Check file content
puts "\n\n📁 Checking input file..."
if response['input_file_id']
  begin
    file_content = client.files.content(id: response['input_file_id'])
    puts "Input file content (first 500 chars):"
    puts file_content.to_s[0..500]
  rescue => e
    puts "Error reading input file: #{e.message}"
  end
end