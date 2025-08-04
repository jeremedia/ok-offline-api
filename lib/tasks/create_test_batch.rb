#!/usr/bin/env ruby
require_relative '../../config/environment'

# Create a small test batch to verify webhook system
puts "🧪 Creating test batch for webhook verification"

# Get 5 items without embeddings
test_items = SearchableItem.where(embedding: nil).limit(5)

if test_items.empty?
  puts "❌ No items without embeddings found"
  exit 1
end

puts "📋 Test items:"
test_items.each_with_index do |item, i|
  puts "   #{i+1}. #{item.name} (#{item.item_type}, #{item.year})"
end

# Set webhook secret if provided as argument
if ARGV[0]
  ENV['OPENAI_WEBHOOK_SECRET'] = ARGV[0]
  puts "🔐 Webhook secret set from argument"
end

# Create batch
batch_service = Search::BatchEmbeddingService.new

begin
  result = batch_service.queue_batch_job(
    test_items,
    description: "Test webhook batch (5 items)"
  )
  
  puts "✅ Test batch created!"
  puts "   OpenAI Batch ID: #{result[:openai_batch_id]}"
  puts "   Local Batch ID: #{result[:local_batch_id]}"
  puts "   Cost: ~$0.0001"
  
  puts "\n📍 Next steps:"
  puts "   1. Configure webhook in OpenAI dashboard:"
  puts "      URL: https://your-domain.com/api/v1/webhooks/openai_batch"
  puts "      Events: batch.completed, batch.failed, batch.expired"
  puts "   2. Wait for completion (usually <1 hour for small batches)"
  puts "   3. Check results with: rails burning_man:report"
  
rescue => e
  puts "❌ Failed: #{e.message}"
  puts "   #{e.class}: #{e.backtrace.first}"
end