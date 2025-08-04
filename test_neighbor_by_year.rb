#!/usr/bin/env ruby
require_relative 'config/environment'

puts "Testing neighbor search results by year..."
puts "=" * 60

# Generate a test embedding for "temple"
embedding_service = Search::EmbeddingService.new
query_embedding = embedding_service.generate_embedding("temple")

if query_embedding.nil?
  puts "Failed to generate embedding!"
  exit 1
end

puts "Generated query embedding with #{query_embedding.length} dimensions"
puts "\nSearching for 'temple' across all years:\n"

# Get all years with data
years = SearchableItem.where.not(embedding: nil).distinct.pluck(:year).sort

results_by_year = {}

years.each do |year|
  begin
    # Search for temple in each year
    results = SearchableItem
      .where(year: year)
      .with_embedding
      .nearest_neighbors(:embedding, query_embedding, distance: "cosine")
      .limit(10)
      .to_a
    
    results_by_year[year] = results.length
  rescue => e
    results_by_year[year] = "Error: #{e.class}"
  end
end

# Display results as a chart
puts "Year | Result Count | Visual"
puts "-" * 50

results_by_year.each do |year, count|
  if count.is_a?(Integer)
    bar = "█" * [count, 20].min
    puts "#{year} | #{count.to_s.rjust(12)} | #{bar}"
  else
    puts "#{year} | #{count.to_s.rjust(12)} |"
  end
end

# Check specific 2017 items
puts "\n\nChecking 2017 temple items specifically:"
temple_2017 = SearchableItem.where(year: 2017).where("name ILIKE ?", "%temple%").first(3)
temple_2017.each do |item|
  puts "\n#{item.name}:"
  puts "  - Has embedding: #{!item.embedding.nil?}"
  puts "  - Embedding dimensions: #{item.embedding&.length}"
  puts "  - Searchable text: #{item.searchable_text&.truncate(100)}"
end

# Test with a different query
puts "\n\nTesting with 'art' query:"
art_embedding = embedding_service.generate_embedding("art")
if art_embedding
  art_results = SearchableItem
    .where(year: 2017)
    .with_embedding
    .nearest_neighbors(:embedding, art_embedding, distance: "cosine")
    .limit(5)
    .to_a
  
  puts "Found #{art_results.length} results for 'art' in 2017"
end