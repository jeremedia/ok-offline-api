#!/usr/bin/env ruby
require_relative '../../config/environment'

# Process the completed embeddings batch with detailed logging
batch_id = 'batch_688beda27b34819082864054e38bf33e'

puts "🚀 Processing Embeddings Batch"
puts "=" * 50

# Check current status
total_items = SearchableItem.count
without_embeddings = SearchableItem.where(embedding: nil).count
with_embeddings = SearchableItem.where.not(embedding: nil).count

puts "📊 Current Status:"
puts "   Total items: #{total_items}"
puts "   With embeddings: #{with_embeddings}"
puts "   Without embeddings: #{without_embeddings}"
puts ""

# Get batch details from OpenAI
client = OpenAI::Client.new(api_key: ENV['OPENAI_API_KEY'])

begin
  puts "🔍 Fetching batch details from OpenAI..."
  batch = client.batches.retrieve(id: batch_id)
  
  puts "   Status: #{batch['status']}"
  puts "   Total requests: #{batch['request_counts']['total']}"
  puts "   Completed: #{batch['request_counts']['completed']}"
  puts "   Failed: #{batch['request_counts']['failed']}"
  
  unless batch['status'] == 'completed'
    puts "❌ Batch not completed yet!"
    exit 1
  end
  
  output_file_id = batch['output_file_id']
  puts "   Output file: #{output_file_id}"
  puts ""
  
  puts "📥 Downloading results file..."
  file_content = client.files.content(id: output_file_id)
  
  puts "   File type: #{file_content.class}"
  
  if file_content.is_a?(Array)
    puts "   Results count: #{file_content.length}"
  elsif file_content.is_a?(String)
    puts "   File size: #{file_content.length} bytes"
  elsif file_content.is_a?(Hash)
    puts "   Single result"
  end
  
  puts ""
  puts "🔄 Processing embeddings..."
  puts "   This will take several minutes for 46,975 items..."
  
  # Process in batches for better performance
  results_processed = 0
  errors_found = 0
  batch_size = 100
  
  if file_content.is_a?(Array)
    file_content.each_slice(batch_size) do |batch_results|
      updates = []
      
      batch_results.each do |result|
        if result['response'] && result['response']['status_code'] == 200
          custom_id = result['custom_id']
          item_id = custom_id.split('_').last.to_i
          embedding = result['response']['body']['data'][0]['embedding']
          
          updates << { id: item_id, embedding: embedding }
        else
          errors_found += 1
        end
      end
      
      # Bulk update for efficiency
      unless updates.empty?
        updates.each do |update|
          SearchableItem.where(id: update[:id]).update_all(embedding: update[:embedding])
          results_processed += 1
        end
      end
      
      # Progress update every 1000 items
      if results_processed % 1000 == 0
        puts "   Processed: #{results_processed}/#{file_content.length} (#{(results_processed.to_f / file_content.length * 100).round(1)}%)"
      end
    end
  else
    puts "❌ Unexpected file format: #{file_content.class}"
    exit 1
  end
  
  puts ""
  puts "✅ Processing complete!"
  puts "   Embeddings processed: #{results_processed}"
  puts "   Errors: #{errors_found}"
  
  # Final check
  final_without = SearchableItem.where(embedding: nil).count
  final_with = SearchableItem.where.not(embedding: nil).count
  
  puts ""
  puts "📊 Final Status:"
  puts "   With embeddings: #{final_with} (was #{with_embeddings})"
  puts "   Without embeddings: #{final_without} (was #{without_embeddings})"
  puts "   Embeddings added: #{final_with - with_embeddings}"
  
rescue => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace.first(10).join("\n")
  exit 1
end