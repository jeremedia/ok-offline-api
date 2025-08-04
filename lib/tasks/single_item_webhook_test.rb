#!/usr/bin/env ruby
require_relative '../../config/environment'

# Create the smallest possible test: just 1 item to verify webhook flow
puts "🧪 Single Item Webhook Test"
puts "=" * 40

# Find exactly 1 item without embedding
test_item = SearchableItem.where(embedding: nil).first

unless test_item
  puts "❌ No items without embeddings found"
  exit 1
end

puts "📋 Test Item:"
puts "   ID: #{test_item.id}"
puts "   Name: #{test_item.name}"
puts "   Type: #{test_item.item_type}"
puts "   Year: #{test_item.year}"
puts "   Text: #{test_item.searchable_text[0..100]}..."

# Confirm webhook secret is set
unless ENV['OPENAI_WEBHOOK_SECRET']
  puts "❌ OPENAI_WEBHOOK_SECRET not set"
  exit 1
end

puts "\n🔐 Webhook secret: #{ENV['OPENAI_WEBHOOK_SECRET'][0..20]}..."

# Create batch with just this 1 item
batch_service = Search::BatchEmbeddingService.new

puts "\n🚀 Creating single-item batch..."

begin
  result = batch_service.queue_batch_job(
    SearchableItem.where(id: test_item.id),
    description: "Single item webhook test - #{test_item.name}"
  )
  
  openai_batch_id = result[:openai_batch_id]
  local_batch_id = result[:local_batch_id]
  
  puts "✅ Single-item batch created!"
  puts "   OpenAI Batch ID: #{openai_batch_id}"
  puts "   Local Batch ID: #{local_batch_id}"
  puts "   Cost: ~$0.000002 (minimal)"
  
  puts "\n⏰ Expected Timeline:"
  puts "   • Batch validation: ~30 seconds"
  puts "   • Processing: ~5-30 minutes" 
  puts "   • Webhook delivery: Immediate after completion"
  puts "   • Background job: ~5 seconds"
  
  puts "\n🔍 How to monitor:"
  puts "   1. OpenAI Console: https://platform.openai.com/batches/#{openai_batch_id}"
  puts "   2. Rails logs: tail -f log/development.log | grep -E '(webhook|batch)'"
  puts "   3. Check embedding: rails runner \"puts SearchableItem.find(#{test_item.id}).embedding ? 'HAS EMBEDDING ✅' : 'NO EMBEDDING ❌'\""
  
  puts "\n📊 Status check command:"
  puts "   rails runner \"
client = OpenAI::Client.new(api_key: ENV['OPENAI_API_KEY'])
batch = client.batches.retrieve(id: '#{openai_batch_id}')
puts \\\"Status: \#{batch['status']} (\#{batch['request_counts']['completed']}/\#{batch['request_counts']['total']})\\\"
\""

  puts "\n🎯 Success indicators:"
  puts "   1. Batch status changes to 'completed'"  
  puts "   2. Rails log shows: 'Received OpenAI webhook'"
  puts "   3. Rails log shows: 'Batch completed: #{openai_batch_id}'"
  puts "   4. Background job processes results"
  puts "   5. Item #{test_item.id} has embedding vector"
  
rescue => e
  puts "❌ Failed to create batch: #{e.message}"
  puts "   Error: #{e.class}"
  exit 1
end