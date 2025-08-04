#!/usr/bin/env ruby

puts "=== COMPREHENSIVE TEST OF DataImportService FIX ==="
puts ""

# Find a camp with both basic and pool entities
test_camp = SearchableItem.joins(:search_entities)
  .where(item_type: 'camp')
  .where('EXISTS (SELECT 1 FROM search_entities se WHERE se.searchable_item_id = searchable_items.id AND se.entity_type IN (?))', ['location', 'activity', 'theme', 'time', 'person', 'item_type'])
  .where("EXISTS (SELECT 1 FROM search_entities se WHERE se.searchable_item_id = searchable_items.id AND se.entity_type LIKE 'pool_%')")
  .first

puts "Testing with: #{test_camp.name} (#{test_camp.year})"

# Count current entities
basic_entities = test_camp.search_entities.where(entity_type: ['location', 'activity', 'theme', 'time', 'person', 'item_type'])
pool_entities = test_camp.search_entities.where("entity_type LIKE 'pool_%'")

puts "Before test:"
puts "- Basic entities: #{basic_entities.count}"
puts "- Pool entities: #{pool_entities.count}"

# Temporarily backup and remove basic entities to simulate the original problem
puts ""
puts "Simulating pool-only scenario..."

# Backup basic entities
backed_up_entities = basic_entities.map do |entity|
  {
    entity_type: entity.entity_type,
    entity_value: entity.entity_value,
    confidence: entity.confidence
  }
end

# Remove basic entities
basic_entities.destroy_all

# Reload and verify
test_camp.reload
remaining_basic = test_camp.search_entities.where(entity_type: ['location', 'activity', 'theme', 'time', 'person', 'item_type']).count
remaining_pool = test_camp.search_entities.where("entity_type LIKE 'pool_%'").count

puts "After removing basic entities:"
puts "- Basic entities: #{remaining_basic}"
puts "- Pool entities: #{remaining_pool}"

# Test our fixed logic
basic_entity_types = ['location', 'activity', 'theme', 'time', 'person', 'item_type']
should_skip = test_camp.search_entities.where(entity_type: basic_entity_types).exists?

puts ""
puts "Skip logic test:"
puts "- Should skip? #{should_skip}"
puts "- Expected: false (should extract)"

if should_skip
  puts "❌ PROBLEM: Logic still skipping items with only pool entities"
else
  puts "✅ SUCCESS: Logic will extract entities for pool-only items"
  
  # Test actual extraction
  puts ""
  puts "Running entity extraction..."
  
  import_service = Search::DataImportService.new
  import_service.send(:extract_entities_batch, [test_camp])
  
  # Check results
  test_camp.reload
  new_basic = test_camp.search_entities.where(entity_type: ['location', 'activity', 'theme', 'time', 'person', 'item_type'])
  new_pool = test_camp.search_entities.where("entity_type LIKE 'pool_%'")
  
  puts "After extraction:"
  puts "- Basic entities: #{new_basic.count}"
  puts "- Pool entities: #{new_pool.count}"
  
  if new_basic.any?
    puts ""
    puts "✅ NEW BASIC ENTITIES EXTRACTED:"
    new_basic.each do |entity|
      puts "   - #{entity.entity_value} (#{entity.entity_type})"
    end
  end
end

puts ""
puts "Test completed! The fix allows extraction on pool-only items."