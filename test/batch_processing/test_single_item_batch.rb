#!/usr/bin/env ruby
require_relative 'config/environment'

puts "🧪 Testing Full Batch Loop with Single Item"
puts "=" * 60

# Get one item that needs pool entities
test_item = SearchableItem
  .joins("LEFT JOIN search_entities ON search_entities.searchable_item_id = searchable_items.id AND search_entities.entity_type LIKE 'pool_%'")
  .where("search_entities.id IS NULL")
  .where.not(description: nil)
  .where.not(description: '')
  .where("LENGTH(description) > 50")
  .first

unless test_item
  puts "❌ No items found that need pool entities"
  exit
end

puts "\n📄 Test Item:"
puts "  Name: #{test_item.name}"
puts "  Type: #{test_item.item_type}"
puts "  Description: #{test_item.description.truncate(150)}"
puts "  Current entities: #{test_item.search_entities.count}"

# Create batch
puts "\n🚀 Submitting single-item batch..."
service = Search::BatchPoolEntityExtractionService.new

batch_ids = service.submit_batch_extraction([test_item])

if batch_ids.any?
  batch_id = batch_ids.first
  puts "\n✅ Batch submitted!"
  puts "  Batch ID: #{batch_id}"
  
  # Get the BatchJob record
  batch_job = BatchJob.find_by(batch_id: batch_id)
  if batch_job
    puts "\n📊 Batch Details:"
    puts "  Status: #{batch_job.status}"
    puts "  Estimated cost: $#{'%.6f' % batch_job.estimated_cost}"
    puts "  Created: #{batch_job.created_at}"
  end
  
  puts "\n⏳ Waiting for webhook..."
  puts "  The batch will complete and trigger the webhook"
  puts "  Monitor with: rails batches:status"
  puts "  Or check: rails 'search:batch_status[#{batch_id}]'"
else
  puts "\n❌ Failed to submit batch"
end