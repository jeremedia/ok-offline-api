#!/usr/bin/env ruby
require_relative 'config/environment'

puts "🧪 Testing Pool Entity Extraction"
puts "=" * 60

# Get one item of each enliterated type
test_items = [
  SearchableItem.where(item_type: 'philosophical_text').first,
  SearchableItem.where(item_type: 'experience_story').first,  
  SearchableItem.where(item_type: 'practical_guide').first
].compact

if test_items.empty?
  puts "❌ No enliterated items found to test"
  exit
end

service = Search::PoolEntityExtractionService.new

test_items.each do |item|
  puts "\n📄 Testing: #{item.name} (#{item.item_type})"
  puts "   Text preview: #{item.searchable_text.truncate(150)}"
  
  # Extract pool entities
  entities = service.extract_pool_entities(item.searchable_text, item.item_type)
  
  puts "\n   🌊 Extracted #{entities.count} pool entities:"
  
  # Group by pool
  entities.group_by { |e| e[:type] }.each do |pool, pool_entities|
    puts "   #{pool}: #{pool_entities.count} entities"
    pool_entities.first(3).each do |entity|
      puts "     • #{entity[:value]}"
    end
    puts "     ..." if pool_entities.count > 3
  end
end

puts "\n✅ Test complete!"