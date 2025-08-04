#!/usr/bin/env ruby
require_relative 'config/environment'

puts "🤖 Testing Fully Automated Batch Processing"
puts "=" * 60

# Get a few items that need pool entities
test_items = SearchableItem
  .joins("LEFT JOIN search_entities ON search_entities.searchable_item_id = searchable_items.id AND search_entities.entity_type LIKE 'pool_%'")
  .where("search_entities.id IS NULL")
  .where.not(description: nil)
  .where.not(description: '')
  .where("LENGTH(description) > 50")
  .limit(3)  # Small batch for testing

if test_items.empty?
  puts "❌ No items found that need pool entities"
  exit
end

puts "\n📄 Test Items (#{test_items.count}):"
test_items.each_with_index do |item, idx|
  puts "  #{idx + 1}. #{item.name} (#{item.item_type})"
  puts "     #{item.description.truncate(80)}"
end

# Check Solid Queue status
pending_jobs = SolidQueue::Job.where(finished_at: nil).count
puts "\n📋 Solid Queue Status:"
puts "  Pending jobs: #{pending_jobs}"
puts "  Worker running: #{pending_jobs > 0 ? 'Check if bin/jobs is running' : 'Ready'}"

# Submit batch
puts "\n🚀 Submitting automated test batch..."
service = Search::BatchPoolEntityExtractionService.new

batch_ids = service.submit_batch_extraction(test_items)

if batch_ids.any?
  batch_id = batch_ids.first
  batch_job = BatchJob.find_by(batch_id: batch_id)
  
  puts "\n✅ Batch submitted successfully!"
  puts "  Batch ID: #{batch_id}"
  puts "  Database ID: #{batch_job.id}"
  puts "  Status: #{batch_job.status}"
  puts "  Estimated cost: $#{'%.4f' % batch_job.estimated_cost}"
  
  puts "\n🤖 Automation Pipeline:"
  puts "  1. ⏳ Waiting for OpenAI to process batch..."
  puts "  2. 🔔 Webhook will arrive when complete"
  puts "  3. ✅ ProcessBatchResultsJob will run automatically"
  puts "  4. 🌊 Pool entities will be extracted"
  puts "  5. 💰 Costs will be tracked"
  
  puts "\n📊 Monitor progress:"
  puts "  - Batch status: rails batches:status"
  puts "  - Job queue: rails runner 'p SolidQueue::Job.where(finished_at: nil).count'"
  puts "  - Logs: tail -f log/development.log | grep -E '(Batch|webhook|Processing)'"
  
  puts "\n💡 The entire process is now hands-free!"
else
  puts "\n❌ Failed to submit batch"
end