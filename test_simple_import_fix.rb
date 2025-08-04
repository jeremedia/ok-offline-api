#!/usr/bin/env ruby

puts "=== TESTING FIXED DataImportService (Simplified) ==="
puts ""

# Find a few specific items that only have pool entities
# We know from earlier that OKNOTOK has only pool entities
oknotok_camp = SearchableItem.where('name ILIKE ?', 'OKNOTOK').where(item_type: 'camp').first

# Find another camp that has only pool entities  
test_items = [oknotok_camp].compact

if test_items.empty?
  puts "No suitable test items found"
  exit
end

puts "Testing with #{test_items.count} items:"
test_items.each do |item|
  basic_entities = item.search_entities.where(entity_type: ['location', 'activity', 'theme', 'time', 'person', 'item_type'])
  pool_entities = item.search_entities.where(entity_type: ['pool_idea', 'pool_manifest', 'pool_experience', 'pool_relational', 'pool_evolutionary', 'pool_practical', 'pool_emanation'])
  
  puts "- #{item.name} (#{item.item_type}, #{item.year})"
  puts "  Before: #{basic_entities.count} basic, #{pool_entities.count} pool entities"
end
puts ""

# Test the fixed import service
import_service = Search::DataImportService.new

puts "--- Running extract_entities_batch with fixed logic ---"
import_service.send(:extract_entities_batch, test_items)

puts ""
puts "--- Results ---"
test_items.each do |item|
  item.reload
  basic_entities = item.search_entities.where(entity_type: ['location', 'activity', 'theme', 'time', 'person', 'item_type'])
  pool_entities = item.search_entities.where(entity_type: ['pool_idea', 'pool_manifest', 'pool_experience', 'pool_relational', 'pool_evolutionary', 'pool_practical', 'pool_emanation'])
  
  puts "#{item.name}:"
  puts "  After: #{basic_entities.count} basic, #{pool_entities.count} pool entities"
  
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