#!/usr/bin/env ruby
require_relative 'config/environment'

puts "🧪 Testing Batch Pool Entity Extraction"
puts "=" * 60

# Get items that need pool entities
items_needing_extraction = SearchableItem
  .joins("LEFT JOIN search_entities ON search_entities.searchable_item_id = searchable_items.id AND search_entities.entity_type LIKE 'pool_%'")
  .where("search_entities.id IS NULL")
  .where.not(description: nil)
  .where.not(description: '')
  .where("LENGTH(description) > 20") # Skip very short descriptions
  .limit(100)

puts "📊 Found #{items_needing_extraction.count} items for test batch"

# Show breakdown
items_by_type = items_needing_extraction.group_by(&:item_type)
puts "\nBy type:"
items_by_type.each do |type, items|
  puts "  - #{type}: #{items.count}"
end

# Show some examples
puts "\n📄 Sample items:"
items_needing_extraction.first(5).each do |item|
  puts "  - #{item.name} (#{item.item_type})"
  puts "    #{item.description.truncate(100)}"
end

# Create batch extraction service
puts "\n🚀 Submitting batch extraction..."
batch_service = Search::BatchPoolEntityExtractionService.new

# Submit batch
batch_ids = batch_service.submit_batch_extraction(items_needing_extraction)

if batch_ids.any?
  puts "\n✅ Test batch submitted successfully!"
  puts "Batch IDs: #{batch_ids.join(', ')}"
  puts "\nTo check status, run:"
  batch_ids.each do |id|
    puts "  ruby -r './config/environment' -e \"puts Search::BatchPoolEntityExtractionService.new.check_batch_status('#{id}')\""
  end
else
  puts "\n❌ Failed to submit test batch"
end