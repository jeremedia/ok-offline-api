#!/usr/bin/env ruby
require_relative 'config/environment'

puts "🔍 Finding items with substantial descriptions for entity extraction..."

# Find items with good descriptions
items_with_content = SearchableItem
  .where.not(description: nil)
  .where.not(description: '')
  .where("LENGTH(description) > 100")
  .limit(10)

puts "\nFound #{items_with_content.count} items with descriptions > 100 chars:"

items_with_content.each_with_index do |item, idx|
  puts "\n#{idx + 1}. #{item.name} (#{item.item_type})"
  puts "   Description: #{item.description.truncate(200)}"
  puts "   Length: #{item.description.length} chars"
end

# Select a few diverse items for testing
selected_items = [
  SearchableItem.where(item_type: 'philosophical_text').where("LENGTH(description) > 100").first,
  SearchableItem.where(item_type: 'experience_story').where("LENGTH(description) > 100").first,
  SearchableItem.where(item_type: 'practical_guide').where("LENGTH(description) > 100").first,
  SearchableItem.where(item_type: 'art').where("LENGTH(description) > 100").first,
  SearchableItem.where(item_type: 'camp').where("LENGTH(description) > 100").first
].compact

puts "\n\n🎯 Selected #{selected_items.count} diverse items for entity extraction test:"

selected_items.each do |item|
  puts "\n- #{item.name} (#{item.item_type})"
  puts "  Description preview: #{item.description.truncate(100)}"
end

# Run entity extraction on these items
puts "\n\n🧠 Running entity extraction..."

service = Search::EntityExtractionService.new

selected_items.each do |item|
  puts "\n  Extracting entities for: #{item.name}"
  
  # Extract entities
  entities = service.extract_entities(item.searchable_text, item.item_type)
  
  # Save entities
  entities.each do |entity|
    SearchEntity.find_or_create_by(
      searchable_item: item,
      entity_type: entity[:type],
      entity_value: entity[:value]
    )
  end
end

puts "\n✅ Entity extraction test completed!"

# Show results
selected_items.each do |item|
  item.reload
  entities = item.search_entities
  
  puts "\n📊 #{item.name}:"
  puts "   Total entities: #{entities.count}"
  
  entities.group(:entity_type).count.each do |type, count|
    puts "   - #{type}: #{count}"
    sample_values = entities.where(entity_type: type).limit(3).pluck(:entity_value)
    sample_values.each do |value|
      puts "     • #{value}"
    end
  end
end