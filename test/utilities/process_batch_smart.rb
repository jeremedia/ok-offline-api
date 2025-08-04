#\!/usr/bin/env ruby
require_relative 'config/environment'

batch_id = 'batch_688beda27b34819082864054e38bf33e'

puts "🚀 Smart Batch Processing"
puts "=" * 50

# Check current status
total_items = SearchableItem.count
with_embeddings = SearchableItem.where.not(embedding: nil).count
without_embeddings = SearchableItem.where(embedding: nil).count

puts "📊 Current Status:"
puts "   Total items: #{total_items}"
puts "   With embeddings: #{with_embeddings} (#{(with_embeddings.to_f / total_items * 100).round(1)}%)"
puts "   Without embeddings: #{without_embeddings}"
puts ""

# Get items still needing embeddings
items_needing = SearchableItem.where(embedding: nil).pluck(:id)
puts "🔍 Items still needing embeddings: #{items_needing.count}"

if items_needing.empty?
  puts "✅ All items already have embeddings\!"
  exit 0
end

# Get batch info
client = OpenAI::Client.new(api_key: ENV['OPENAI_API_KEY'])

begin
  puts "📥 Checking batch status..."
  batch = client.batches.retrieve(id: batch_id)
  
  unless batch['status'] == 'completed'
    puts "❌ Batch not completed. Status: #{batch['status']}"
    exit 1
  end
  
  puts "   Batch is completed ✅"
  puts "   Output file: #{batch['output_file_id']}"
  
  # Check if we've already downloaded results
  cache_key = "batch_results_#{batch_id}_content"
  cached_results = Rails.cache.read(cache_key)
  
  if cached_results
    puts "📦 Using cached results"
    file_content = cached_results
  else
    puts "📥 Downloading fresh results..."
    file_content = client.files.content(id: batch['output_file_id'])
    
    # Cache for 24 hours
    Rails.cache.write(cache_key, file_content, expires_in: 24.hours)
    puts "   Cached results for future use"
  end
  
  unless file_content.is_a?(Array)
    puts "❌ Unexpected format: #{file_content.class}"
    exit 1
  end
  
  puts "   Found #{file_content.length} results"
  
  # Process only items that still need embeddings
  puts ""
  puts "🔄 Processing only items without embeddings..."
  
  processed = 0
  skipped = 0
  errors = 0
  
  file_content.each_with_index do |result, index|
    if index % 5000 == 0 && index > 0
      puts "   Progress: #{index}/#{file_content.length} (#{(index.to_f / file_content.length * 100).round(1)}%)"
    end
    
    if result['response'] && result['response']['status_code'] == 200
      custom_id = result['custom_id']
      item_id = custom_id.split('_').last.to_i
      
      # Skip if not in our list of items needing embeddings
      unless items_needing.include?(item_id)
        skipped += 1
        next
      end
      
      embedding = result['response']['body']['data'][0]['embedding']
      
      # Update only if still null
      updated = SearchableItem.where(id: item_id, embedding: nil)
                             .update_all(embedding: embedding)
      
      if updated > 0
        processed += 1
      else
        skipped += 1
      end
    else
      errors += 1
    end
  end
  
  puts ""
  puts "✅ Processing complete\!"
  puts "   Processed: #{processed}"
  puts "   Skipped (already had embeddings): #{skipped}"
  puts "   Errors: #{errors}"
  
  # Final status
  final_with = SearchableItem.where.not(embedding: nil).count
  final_without = SearchableItem.where(embedding: nil).count
  
  puts ""
  puts "📊 Final Status:"
  puts "   With embeddings: #{final_with} (#{(final_with.to_f / total_items * 100).round(1)}%)"
  puts "   Without embeddings: #{final_without}"
  puts "   Embeddings added this run: #{final_with - with_embeddings}"
  
rescue => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  exit 1
end
