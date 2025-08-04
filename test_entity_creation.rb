#!/usr/bin/env ruby

# Test manual entity creation to debug the issue
puts '🔧 DEBUG: Testing manual entity creation...'

# Use one of our test items
item = SearchableItem.find(131)
puts "Testing with item #{item.id}: #{item.name}"

# Sample extracted data from the batch results we saw earlier
sample_entities_data = {
  'names' => ['Land of Monkey'],
  'locations' => ['7:00 & D'],
  'activities' => ['yoga', 'meditation'],
  'themes' => ['multicultural', 'diversity'],
  'times' => ['2024'],
  'people' => [],
  'item_type' => ['camp'],
  'contact' => ['info@landofmonkey.org'],
  'organizational' => [],
  'services' => [],
  'schedule' => [],
  'requirements' => []
}

puts "\nTesting entity creation..."

# Test the creation logic directly
normalization_service = Search::EntityNormalizationService.new

entity_mappings = {
  'names' => 'location',
  'locations' => 'location',
  'activities' => 'activity',
  'themes' => 'theme',
  'times' => 'time',
  'people' => 'person',
  'item_type' => 'item_type',
  'contact' => 'contact',
  'organizational' => 'organizational',
  'services' => 'service',
  'schedule' => 'schedule',
  'requirements' => 'requirement'
}

entity_mappings.each do |key, entity_type|
  next unless sample_entities_data[key].is_a?(Array)
  
  sample_entities_data[key].each do |value|
    next if value.to_s.strip.empty?
    
    puts "  Processing #{entity_type}: #{value}"
    
    # Normalize the entity value
    normalized_value = normalization_service.normalize_entity(
      entity_type,
      value.to_s.strip
    )
    
    puts "    Normalized to: #{normalized_value}"
    
    # Check if this entity already exists for this item
    existing_entity = item.search_entities.find_by(
      entity_type: entity_type,
      entity_value: normalized_value
    )
    
    if existing_entity
      puts "    ⚠️  Already exists: #{existing_entity.id}"
    else
      puts "    ✅ Creating new entity..."
      begin
        new_entity = SearchEntity.create!(
          searchable_item: item,
          entity_type: entity_type,
          entity_value: normalized_value,
          confidence: 0.9
        )
        puts "    ✅ Created entity #{new_entity.id}"
      rescue => e
        puts "    ❌ Error creating entity: #{e.message}"
      end
    end
  end
end

puts "\n🔍 Verification - checking item #{item.id} entities:"
basic_entity_types = ['location', 'activity', 'theme', 'time', 'person', 'item_type', 
                     'contact', 'organizational', 'service', 'schedule', 'requirement']

basic_entities = item.search_entities.where(entity_type: basic_entity_types)
if basic_entities.any?
  basic_entity_types.each do |entity_type|
    entities = basic_entities.where(entity_type: entity_type)
    if entities.any?
      puts "  #{entity_type}: #{entities.pluck(:entity_value).join(', ')}"
    end
  end
else
  puts "  ❌ Still no basic entities found"
end