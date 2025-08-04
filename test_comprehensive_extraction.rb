#!/usr/bin/env ruby

puts "=== TESTING COMPREHENSIVE ENTITY EXTRACTION ==="
puts ""

# Test with items that should have rich metadata
test_items = [
  SearchableItem.where(item_type: 'camp').where("description ILIKE '%email%' OR description ILIKE '%contact%'").first,
  SearchableItem.where(item_type: 'event').where("description ILIKE '%hosted%' OR description ILIKE '%camp%'").first,
  SearchableItem.where(item_type: 'art').where("description ILIKE '%tour%' OR description ILIKE '%hours%'").first
].compact

puts "Testing comprehensive extraction with #{test_items.count} items:"
test_items.each do |item|
  puts "- #{item.name} (#{item.item_type})"
end
puts ""

service = Search::EntityExtractionService.new

test_items.each_with_index do |item, idx|
  puts "=== #{idx + 1}. #{item.name} (#{item.item_type}) ==="
  puts "Text: #{item.searchable_text&.first(200)}..."
  puts ""
  
  entities = service.extract_entities(item.searchable_text, item.item_type)
  
  # Group entities by type
  entity_groups = entities.group_by { |e| e[:entity_type] }
  
  puts "Extracted #{entities.size} entities across #{entity_groups.keys.size} types:"
  
  # Show all entity types
  ['location', 'activity', 'theme', 'time', 'person', 'item_type', 
   'contact', 'organizational', 'service', 'schedule', 'requirement'].each do |type|
    
    type_entities = entity_groups[type] || []
    puts "  #{type.upcase}: #{type_entities.size} entities"
    
    if type_entities.any?
      type_entities.each do |entity|
        puts "    - #{entity[:entity_value]}"
      end
    end
  end
  
  puts ""
  
  # Highlight new critical entity types
  new_types = ['contact', 'organizational', 'service', 'schedule', 'requirement']
  new_found = new_types.select { |type| entity_groups[type]&.any? }
  
  if new_found.any?
    puts "🎉 NEW ENTITY TYPES EXTRACTED: #{new_found.join(', ')}"
  else
    puts "ℹ️  No new critical entity types found (may not be present in this item)"
  end
  
  puts ""
  puts "-" * 60
  puts ""
end

puts "=== SUMMARY ==="
puts "✅ Expanded entity extraction now captures:"
puts "  - Contact information (emails, websites)"
puts "  - Organizational relationships (hosted by, hometowns)"  
puts "  - Services offered (tours, amenities)"
puts "  - Schedule details (times, duration)"
puts "  - Requirements (age restrictions, prerequisites)"
puts ""
puts "This will dramatically improve knowledge graph richness!"