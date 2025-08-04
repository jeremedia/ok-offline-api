#!/usr/bin/env ruby

# Process all items without entities using batch API
require_relative 'config/environment'

puts "🚀 Batch Entity Extraction for All Items"
puts "=" * 60

# Count items without entities
total_without_entities = SearchableItem.left_joins(:search_entities)
                                      .where(search_entities: { id: nil })
                                      .count

puts "Total items without entities: #{total_without_entities}"

if total_without_entities == 0
  puts "✅ All items already have entities!"
  exit
end

# Process in batches of 1000 (OpenAI recommends 100-1000 per batch)
BATCH_SIZE = 1000
service = Search::BatchEntityExtractionService.new

batches_created = 0
total_processed = 0

SearchableItem.left_joins(:search_entities)
              .where(search_entities: { id: nil })
              .find_in_batches(batch_size: BATCH_SIZE) do |items|
  
  puts "\n📦 Creating batch #{batches_created + 1} with #{items.size} items..."
  
  result = service.queue_batch_extraction(
    items,
    description: "Enliteracy entity extraction batch #{batches_created + 1}"
  )
  
  puts "   ✅ Batch created: #{result[:openai_batch_id]}"
  
  batches_created += 1
  total_processed += items.size
  
  # Add a small delay between batch submissions
  sleep 2
end

puts "\n" + "=" * 60
puts "✅ Summary:"
puts "   Total items processed: #{total_processed}"
puts "   Batches created: #{batches_created}"
puts "   Average items per batch: #{(total_processed.to_f / batches_created).round}"
puts
puts "All batches will process asynchronously via webhooks."
puts "Monitor progress in Rails logs or with:"
puts "  rails runner \"puts SearchEntity.where('entity_type LIKE ?', 'pool_%').count\""