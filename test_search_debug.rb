#!/usr/bin/env ruby
require_relative 'config/environment'

puts "Debugging search for Temple 2017..."
puts "=" * 60

# Test 1: Check if 2017 temple exists
temple_2017 = SearchableItem.where(year: 2017).where("name ILIKE ?", "%temple%").first(5)
puts "\n2017 Temple items in database:"
temple_2017.each do |item|
  puts "- #{item.name} (#{item.item_type}) - Has embedding: #{!item.embedding.nil?}"
end

# Test 2: Generate embedding for search query
embedding_service = Search::EmbeddingService.new
query_embedding = embedding_service.generate_embedding("Temple 2017")
puts "\nGenerated query embedding: #{!query_embedding.nil?}"

if query_embedding
  # Test 3: Direct vector search on 2017 items
  puts "\nTesting direct vector search for year 2017..."
  results = SearchableItem
    .where(year: 2017)
    .with_embedding
    .nearest_neighbors(:embedding, query_embedding, distance: "cosine")
    .limit(5)
    .to_a
  
  puts "Found #{results.length} results:"
  results.each do |item|
    puts "- #{item.name} (#{item.year})"
  end
  
  # Test 4: Vector search service
  puts "\nTesting VectorSearchService..."
  vector_service = Search::VectorSearchService.new
  vector_results = vector_service.search(
    query: "Temple 2017",
    year: 2017,
    limit: 5
  )
  
  puts "VectorSearchService results: #{vector_results[:total_count]}"
  if vector_results[:results].any?
    vector_results[:results].each do |r|
      puts "- #{r[:name]} (#{r[:type]})"
    end
  end
end