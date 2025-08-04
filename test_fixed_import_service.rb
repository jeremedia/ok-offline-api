#!/usr/bin/env ruby

puts "=== TESTING FIXED DataImportService ==="
puts ""

# Find items that have only pool entities (should now get basic entity extraction)
pool_only_items = SearchableItem.joins(:search_entities)
  .where.not(id: SearchableItem.joins(:search_entities).where(search_entities: { entity_type: ['location', 'activity', 'theme', 'time', 'person', 'item_type'] }))
  .where(search_entities: { entity_type: ['pool_idea', 'pool_manifest', 'pool_experience', 'pool_relational', 'pool_evolutionary', 'pool_practical', 'pool_emanation'] })
  .distinct
  .limit(3) # Test with 3 items

puts "Testing with #{pool_only_items.count} items that have only pool entities:"
pool_only_items.each do |item|
  puts "- #{item.name} (#{item.item_type}, #{item.year})"
end
puts ""

# Test the fixed import service
import_service = Search::DataImportService.new

puts "--- Running extract_entities_batch with fixed logic ---"
import_service.send(:extract_entities_batch, pool_only_items)

puts ""
puts "--- Results ---"
pool_only_items.each do |item|
  item.reload
  basic_entities = item.search_entities.where(entity_type: ['location', 'activity', 'theme', 'time', 'person', 'item_type'])
  pool_entities = item.search_entities.where(entity_type: ['pool_idea', 'pool_manifest', 'pool_experience', 'pool_relational', 'pool_evolutionary', 'pool_practical', 'pool_emanation'])
  
  puts "#{item.name}:"
  puts "  Basic entities: #{basic_entities.count} (NEW!)"
  puts "  Pool entities: #{pool_entities.count} (preserved)"
  
  if basic_entities.any?
    puts "  ✅ SUCCESS: Now has basic entities:"
    basic_entities.each do |entity|
      puts "     - #{entity.entity_value} (#{entity.entity_type})"
    end
  else
    puts "  ❌ No basic entities added"
  end
  puts ""
end