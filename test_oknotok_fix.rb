#!/usr/bin/env ruby

# Test the entity extraction fix for OKNOTOK camp
oknotok_camp = SearchableItem.where('name ILIKE ?', 'OKNOTOK').where(item_type: 'camp').first

puts "Current entities for OKNOTOK camp:"
oknotok_camp.search_entities.each do |entity|
  puts "- #{entity.entity_value} (#{entity.entity_type})"
end

puts "\n--- Extracting and saving new entities ---"

# Clear existing basic entities (keep pool entities)
deleted_count = oknotok_camp.search_entities.where(entity_type: ['location', 'activity', 'theme', 'time', 'person', 'item_type']).delete_all
puts "Deleted #{deleted_count} existing basic entities"

# Extract new entities
service = Search::EntityExtractionService.new
entities = service.extract_entities(oknotok_camp.searchable_text, oknotok_camp.item_type)

# Save new entities
entities.each do |entity_data|
  entity = oknotok_camp.search_entities.create!(entity_data)
  puts "Added: #{entity.entity_value} (#{entity.entity_type})"
end

puts "\n--- Final entity list ---"
oknotok_camp.reload.search_entities.each do |entity|
  puts "- #{entity.entity_value} (#{entity.entity_type})"
end

# Check if OKNOTOK is now in the database
oknotok_entity = oknotok_camp.search_entities.find_by(entity_value: 'OKNOTOK')
if oknotok_entity
  puts "\n✅ SUCCESS: OKNOTOK entity saved to database!"
  puts "   Entity ID: #{oknotok_entity.id}"
  puts "   Entity Type: #{oknotok_entity.entity_type}"
else
  puts "\n❌ PROBLEM: OKNOTOK entity not found in database"
end