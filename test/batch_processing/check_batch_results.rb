#!/usr/bin/env ruby
require_relative 'config/environment'

puts "🔍 Checking entity extraction batch results..."

# Check if we have pool entities in the database
pool_entity_types = ['pool_idea', 'pool_manifest', 'pool_experience', 'pool_relational', 
                     'pool_evolutionary', 'pool_practical', 'pool_emanation']

puts "\n📊 Pool Entity Summary:"
pool_entity_types.each do |pool_type|
  count = SearchEntity.where(entity_type: pool_type).count
  if count > 0
    puts "  ✅ #{pool_type}: #{count} entities"
    
    # Show some examples
    examples = SearchEntity.where(entity_type: pool_type).limit(3)
    examples.each do |entity|
      puts "     - #{entity.entity_value} (from: #{entity.searchable_item.name})"
    end
  else
    puts "  ❌ #{pool_type}: 0 entities"
  end
end

# Check total entities by type
puts "\n📊 All Entity Types:"
entity_counts = SearchEntity.group(:entity_type).count.sort_by { |_, count| -count }
entity_counts.each do |type, count|
  puts "  #{type}: #{count}"
end

# Check items that should have pool entities
puts "\n🔍 Checking items that should have pool entities:"

# Philosophical texts
phil_items = SearchableItem.where(item_type: 'philosophical_text')
puts "\n📚 Philosophical Texts (#{phil_items.count} total):"
phil_items.limit(5).each do |item|
  entities = item.search_entities.where(entity_type: pool_entity_types)
  puts "  - #{item.name}: #{entities.count} pool entities"
  if entities.any?
    entities.each { |e| puts "    • #{e.entity_type}: #{e.entity_value}" }
  end
end

# Experience stories
exp_items = SearchableItem.where(item_type: 'experience_story')
puts "\n🎭 Experience Stories (#{exp_items.count} total):"
exp_items.limit(5).each do |item|
  entities = item.search_entities.where(entity_type: pool_entity_types)
  puts "  - #{item.name}: #{entities.count} pool entities"
  if entities.any?
    entities.each { |e| puts "    • #{e.entity_type}: #{e.entity_value}" }
  end
end

# Practical guides
prac_items = SearchableItem.where(item_type: 'practical_guide')
puts "\n🔧 Practical Guides (#{prac_items.count} total):"
prac_items.limit(5).each do |item|
  entities = item.search_entities.where(entity_type: pool_entity_types)
  puts "  - #{item.name}: #{entities.count} pool entities"
  if entities.any?
    entities.each { |e| puts "    • #{e.entity_type}: #{e.entity_value}" }
  end
end