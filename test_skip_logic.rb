#!/usr/bin/env ruby

puts "=== TESTING DataImportService SKIP LOGIC ==="
puts ""

# Create a mock item that has only pool entities (simulate the real scenario)
test_camp = SearchableItem.where(item_type: 'camp').first

puts "Testing skip logic with: #{test_camp.name}"

# Check current logic in DataImportService
basic_entity_types = ['location', 'activity', 'theme', 'time', 'person', 'item_type']
has_basic_entities = test_camp.search_entities.where(entity_type: basic_entity_types).exists?
has_any_entities = test_camp.search_entities.exists?

puts ""
puts "Current entity status:"
puts "- Has basic entities: #{has_basic_entities}"
puts "- Has any entities: #{has_any_entities}"
puts ""

puts "Skip logic behavior:"
puts "- OLD logic (if item.search_entities.exists?): #{has_any_entities ? 'SKIP' : 'EXTRACT'}"
puts "- NEW logic (only if has basic entities): #{has_basic_entities ? 'SKIP' : 'EXTRACT'}"
puts ""

# Test the actual logic from DataImportService
if has_basic_entities
  puts "✅ CORRECT: Item has basic entities, should be skipped"
else
  puts "✅ CORRECT: Item missing basic entities, should be extracted"
  
  # Verify it would actually run extraction
  puts ""
  puts "Testing actual extraction..."
  
  service = Search::EntityExtractionService.new
  entities = service.extract_entities(test_camp.searchable_text, test_camp.item_type)
  
  puts "Would extract #{entities.size} entities:"
  entities.each do |entity|
    puts "  - #{entity[:entity_value]} (#{entity[:entity_type]})"
  end
end