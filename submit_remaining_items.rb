#!/usr/bin/env ruby
require_relative 'config/environment'

puts "🚀 Submitting Remaining Items for Pool Extraction"
puts "=" * 60

# Get remaining items that need pool entities
remaining_items = SearchableItem
  .joins("LEFT JOIN search_entities ON search_entities.searchable_item_id = searchable_items.id AND search_entities.entity_type LIKE 'pool_%'")
  .where("search_entities.id IS NULL")
  .where.not(description: nil)
  .where.not(description: '')
  .where("LENGTH(description) > 50")

count = remaining_items.count
puts "\n📊 Found #{count} items still needing pool extraction"

if count == 0
  puts "✅ All items already processed!"
  exit
end

# Show breakdown by type
puts "\nBy type:"
remaining_items.group(:item_type).count.each do |type, type_count|
  puts "  - #{type}: #{type_count}"
end

# Cost estimation
service = Search::BatchPoolEntityExtractionService.new
batch_size = Search::BatchPoolEntityExtractionService::BATCH_SIZE
num_batches = (count.to_f / batch_size).ceil
estimated_tokens = count * 700
estimated_cost = (estimated_tokens / 1_000_000.0) * 0.20 * 2

puts "\n💰 Cost Estimate:"
puts "  Items: #{count}"
puts "  Number of batches: #{num_batches}"
puts "  Estimated cost: $#{'%.2f' % estimated_cost}"
puts "  Cost per item: $#{'%.4f' % (estimated_cost / count)}"

puts "\n❓ Submit these remaining items? (y/n)"
response = gets.chomp.downcase

if response == 'y'
  puts "\n🚀 Submitting batches..."
  
  batch_ids = service.submit_batch_extraction(remaining_items)
  
  if batch_ids.any?
    puts "\n✅ Successfully submitted #{batch_ids.count} batches!"
    batch_ids.each_with_index do |batch_id, idx|
      batch_job = BatchJob.find_by(batch_id: batch_id)
      puts "  #{idx + 1}. Batch #{batch_job.id}: #{batch_job.total_items} items"
    end
    
    total_submitted = BatchJob.where(batch_id: batch_ids).sum(:total_items)
    puts "\nTotal items submitted: #{total_submitted}"
    puts "\n✅ All remaining items have been submitted for processing!"
  else
    puts "\n❌ Failed to submit batches"
  end
else
  puts "\n❌ Submission cancelled"
end