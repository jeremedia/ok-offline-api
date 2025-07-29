#!/usr/bin/env ruby
require_relative 'config/environment'

puts "Testing Different Search Queries..."
puts "==================================="

search_service = Search::VectorSearchService.new

# Test 1: Camp search
puts "\n1. Searching for camps with coffee:"
result = search_service.search(
  query: "coffee and espresso camps",
  year: 2024,
  item_types: ['camp'],
  limit: 3
)

result[:results].each do |item|
  puts "- #{item[:name]} (Score: #{item[:similarity_score]})"
end

# Test 2: Art search
puts "\n2. Searching for interactive art:"
result = search_service.search(
  query: "interactive art installations that people can touch and play with",
  year: 2024,
  item_types: ['art'],
  limit: 3
)

result[:results].each do |item|
  puts "- #{item[:name]} (Score: #{item[:similarity_score]})"
end

# Test 3: Hybrid search
puts "\n3. Testing hybrid search for 'fire':"
result = search_service.hybrid_search(
  query: "fire",
  year: 2024,
  limit: 5
)

result[:results].each do |item|
  puts "- #{item[:name]} (#{item[:type]}) - Search type: #{result[:search_type]}"
end

# Test 4: Entity-based search
puts "\n4. Testing entity search:"
result = search_service.entity_search(
  entities: ["workshops", "massage"],
  year: 2024,
  limit: 3
)

result[:results].each do |item|
  puts "- #{item[:name]} (#{item[:type]})"
end

# Show some extracted entities
puts "\n5. Sample extracted entities:"
SearchEntity.limit(10).each do |entity|
  puts "- #{entity.entity_type}: #{entity.entity_value}"
end