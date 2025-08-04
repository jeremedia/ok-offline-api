#!/usr/bin/env ruby
require_relative 'config/environment'

puts "Testing vector search service..."
puts "=" * 60

service = Search::VectorSearchService.new
begin
  # Test embedding generation
  embedding_service = Search::EmbeddingService.new
  embedding = embedding_service.generate_embedding("temple")
  puts "Embedding generated: #{!embedding.nil?}"
  puts "Embedding dimensions: #{embedding&.length}"
  
  # Test vector search
  results = service.search(
    query: "temple",
    year: 2025,
    limit: 10
  )
  
  puts "\nVector search results:"
  puts "Total results: #{results[:total_count]}"
  puts "Search type: #{results[:search_type]}"
  puts "Error: #{results[:error]}" if results[:error]
  
  if results[:results].any?
    results[:results].first(3).each do |result|
      puts "\n- #{result[:name]}"
      puts "  Type: #{result[:type]}"
      puts "  Similarity: #{result[:similarity_score]}"
    end
  end
  
  # Check what years have data
  years_with_data = SearchableItem.where.not(embedding: nil).distinct.pluck(:year).sort
  puts "\n\nYears with embedded data: #{years_with_data.join(', ')}"
  
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end