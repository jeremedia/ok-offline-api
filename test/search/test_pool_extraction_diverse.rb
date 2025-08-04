#!/usr/bin/env ruby
require_relative 'config/environment'

puts "🧪 Testing Pool Entity Extraction on Diverse Items"
puts "=" * 60

# Get a diverse sample: regular items + enliterated items
test_items = []

# Get some regular items with good descriptions
test_items += SearchableItem
  .where(item_type: ['camp', 'art', 'event'])
  .where("LENGTH(description) > 100")
  .order('RANDOM()')
  .limit(20)

# Get some items with minimal descriptions
test_items += SearchableItem
  .where(item_type: ['camp', 'art', 'event'])
  .where("LENGTH(description) BETWEEN 10 AND 50")
  .order('RANDOM()')
  .limit(10)

# Get some items with no descriptions
test_items += SearchableItem
  .where(item_type: ['camp', 'art', 'event'])
  .where("description IS NULL OR description = ''")
  .limit(5)

# Add some enliterated items we haven't processed
test_items += SearchableItem
  .where(item_type: ['philosophical_text', 'experience_story', 'practical_guide'])
  .joins("LEFT JOIN search_entities ON search_entities.searchable_item_id = searchable_items.id AND search_entities.entity_type LIKE 'pool_%'")
  .where("search_entities.id IS NULL")
  .limit(15)

puts "📊 Test Sample Summary:"
puts "  Total items: #{test_items.count}"
puts "\nBy type:"
test_items.group_by(&:item_type).each do |type, items|
  puts "  - #{type}: #{items.count}"
end

puts "\nBy description length:"
puts "  - No description: #{test_items.select { |i| i.description.blank? }.count}"
puts "  - Short (10-50 chars): #{test_items.select { |i| i.description.present? && i.description.length.between?(10, 50) }.count}"
puts "  - Medium (50-200 chars): #{test_items.select { |i| i.description.present? && i.description.length.between?(50, 200) }.count}"
puts "  - Long (200+ chars): #{test_items.select { |i| i.description.present? && i.description.length > 200 }.count}"

# Test pool extraction
service = Search::PoolEntityExtractionService.new
results = {
  success: 0,
  no_entities: 0,
  errors: 0,
  total_entities: 0
}

puts "\n\n🌊 Running Pool Entity Extraction..."
puts "-" * 40

test_items.each_with_index do |item, idx|
  print "\r⏳ Processing #{idx + 1}/#{test_items.count}..."
  
  begin
    entities = service.extract_pool_entities(item.searchable_text, item.item_type)
    
    if entities.any?
      results[:success] += 1
      results[:total_entities] += entities.count
      
      # Show first few items in detail
      if idx < 5
        puts "\n\n📄 #{item.name} (#{item.item_type})"
        puts "   Description: #{item.description.present? ? item.description.truncate(100) : '[No description]'}"
        puts "   Extracted: #{entities.count} pool entities"
        entities.group_by { |e| e[:type] }.each do |pool, pool_entities|
          puts "   - #{pool}: #{pool_entities.map { |e| e[:value] }.first(3).join(', ')}"
        end
      end
    else
      results[:no_entities] += 1
    end
  rescue => e
    results[:errors] += 1
    puts "\n❌ Error on #{item.name}: #{e.message}"
  end
end

# Summary
puts "\n\n" + "=" * 60
puts "📊 Test Results Summary:"
puts "  ✅ Successful extractions: #{results[:success]}"
puts "  ⚠️  No entities found: #{results[:no_entities]}"
puts "  ❌ Errors: #{results[:errors]}"
puts "  🌊 Total pool entities: #{results[:total_entities]}"
puts "  📈 Average entities per item: #{results[:success] > 0 ? (results[:total_entities].to_f / results[:success]).round(1) : 0}"

# Check entity distribution
puts "\n📊 Entity Distribution by Pool:"
entity_types = %w[pool_idea pool_manifest pool_experience pool_relational 
                  pool_evolutionary pool_practical pool_emanation]

entity_counts = Hash.new(0)
test_items.first(10).each do |item|
  entities = service.extract_pool_entities(item.searchable_text, item.item_type)
  entities.each { |e| entity_counts[e[:type]] += 1 }
end

entity_types.each do |pool|
  puts "  #{pool}: #{entity_counts[pool]}"
end

puts "\n✅ Diverse item test complete!"