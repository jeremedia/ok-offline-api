#!/usr/bin/env ruby

# Strategic Entity Re-Extraction Plan
# Priority: High-impact items first, cost-efficient batching

puts "=== PRIORITIZED ENTITY RE-EXTRACTION PLAN ==="
puts ""

# Phase 1: High-Value Camps (most searchable/recognizable)
high_value_camps = SearchableItem.where(item_type: 'camp')
  .where('name ~* ?', '(center|camp|art|music|sound|temple|burn|fire|dance|love|peace|rainbow|sacred|magic|cosmic|electric|deep|black|white|golden|silver|lounge|bar|cafe|kitchen|stage|dome|palace|village|city|base|station|house|home|sanctuary|oasis|garden|workshop|studio|lab|collective|tribe|family|clan|crew|society|club|circle|space|place|zone|area|point|spot)')
  .where('NOT EXISTS (SELECT 1 FROM search_entities WHERE search_entities.searchable_item_id = searchable_items.id AND LOWER(search_entities.entity_value) LIKE LOWER(CONCAT(\'%\', SPLIT_PART(searchable_items.name, \' \', 1), \'%\')))')

puts "Phase 1 - High-Value Camps: #{high_value_camps.count} items"
puts "Estimated cost: $#{(high_value_camps.count * 0.0002).round(2)} (at ~$0.0002 per extraction)"
puts ""

# Phase 2: Major Art Installations  
art_installations = SearchableItem.where(item_type: 'art')
  .where('NOT EXISTS (SELECT 1 FROM search_entities WHERE search_entities.searchable_item_id = searchable_items.id AND LOWER(search_entities.entity_value) LIKE LOWER(CONCAT(\'%\', SPLIT_PART(searchable_items.name, \' \', 1), \'%\')))')

puts "Phase 2 - Art Installations: #{art_installations.count} items" 
puts "Estimated cost: $#{(art_installations.count * 0.0002).round(2)}"
puts ""

# Phase 3: Events (may need prompt refinement)
events_missing_names = SearchableItem.where(item_type: 'event')
  .where('NOT EXISTS (SELECT 1 FROM search_entities WHERE search_entities.searchable_item_id = searchable_items.id AND LOWER(search_entities.entity_value) LIKE LOWER(CONCAT(\'%\', SPLIT_PART(searchable_items.name, \' \', 1), \'%\')))')

puts "Phase 3 - Events: #{events_missing_names.count} items"
puts "Estimated cost: $#{(events_missing_names.count * 0.0002).round(2)}"
puts ""

# Total Impact
total_items = high_value_camps.count + art_installations.count + events_missing_names.count
total_cost = total_items * 0.0002

puts "TOTAL STRATEGIC RE-EXTRACTION:"
puts "Items: #{total_items}"
puts "Estimated cost: $#{total_cost.round(2)}"
puts ""

# Efficiency Gains
puts "EFFICIENCY GAINS:"
puts "- Targeting only items missing name entities (not all 54k items)"
puts "- Preserving existing pool entities (no re-extraction needed)"
puts "- Batch processing for cost savings"
puts "- High-impact items first for maximum ROI"

# Sample of Phase 1 items
puts ""
puts "Sample Phase 1 High-Value Camps:"
high_value_camps.limit(10).each do |camp|
  puts "- #{camp.name} (#{camp.year})"
end