#!/usr/bin/env ruby
require_relative 'config/environment'

puts "🐛 Debugging Pool Entity Extraction"

# Test with one item
item = SearchableItem.where(item_type: 'philosophical_text').first
puts "Testing with: #{item.name}"

service = Search::PoolEntityExtractionService.new
entities = service.extract_pool_entities(item.searchable_text, item.item_type)

puts "\nExtracted #{entities.count} entities:"
entities.each { |e| puts "  - #{e[:type]}: #{e[:value]}" }

# Try to save manually
puts "\nTrying to save entities..."
entities.each do |entity|
  begin
    se = SearchEntity.find_or_create_by(
      searchable_item: item,
      entity_type: entity[:type],
      entity_value: entity[:value]
    )
    puts "  ✅ Saved: #{se.entity_type} - #{se.entity_value}"
  rescue => e
    puts "  ❌ Error: #{e.message}"
  end
end

# Check what was saved
puts "\nChecking saved entities:"
item.reload
pool_entities = item.search_entities.where("entity_type LIKE 'pool_%'")
puts "Found #{pool_entities.count} pool entities for this item"