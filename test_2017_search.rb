#!/usr/bin/env ruby
require_relative 'config/environment'

puts "Testing 2017 temple search in detail..."
puts "=" * 60

# Get embedding for "temple"
embedding_service = Search::EmbeddingService.new
temple_embedding = embedding_service.generate_embedding("temple")

# Check 2017 temple items
puts "\n2017 items with 'temple' in name:"
temple_items = SearchableItem.where(year: 2017).where("name ILIKE ?", "%temple%")
puts "Found #{temple_items.count} items"
temple_items.limit(10).each do |item|
  puts "  - #{item.name}"
end

# Now do vector search on 2017
puts "\n\nVector search for 'temple' in 2017:"
results = SearchableItem
  .where(year: 2017)
  .nearest_neighbors(:embedding, temple_embedding, distance: "cosine")
  .limit(10)

results_array = results.to_a
puts "Found #{results_array.length} results:"
results_array.each_with_index do |item, i|
  # Calculate distance manually to verify
  distance = 1 - temple_embedding.zip(item.embedding).sum { |a, b| a * b }
  puts "  #{i+1}. #{item.name}"
  puts "     Distance: #{distance.round(4)}"
  puts "     Has 'temple' in name: #{item.name.downcase.include?('temple')}"
end

# Compare with 2024 results
puts "\n\nVector search for 'temple' in 2024 (for comparison):"
results_2024 = SearchableItem
  .where(year: 2024)
  .nearest_neighbors(:embedding, temple_embedding, distance: "cosine")
  .limit(5)

results_2024.each_with_index do |item, i|
  distance = 1 - temple_embedding.zip(item.embedding).sum { |a, b| a * b }
  puts "  #{i+1}. #{item.name} - Distance: #{distance.round(4)}"
end

# Check if it's a semantic search issue
puts "\n\nLet's try searching for something else in 2017:"
art_embedding = embedding_service.generate_embedding("art installation")
art_results = SearchableItem
  .where(year: 2017)
  .nearest_neighbors(:embedding, art_embedding, distance: "cosine")
  .limit(5)

puts "Vector search for 'art installation' in 2017:"
art_results_array = art_results.to_a
puts "Found #{art_results_array.length} results:"
art_results_array.each do |item|
  puts "  - #{item.name} (#{item.item_type})"
end