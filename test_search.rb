#!/usr/bin/env ruby
require_relative 'config/environment'

puts "Testing Vector Search..."
puts "========================"

# Check data
puts "\nTotal items: #{SearchableItem.count}"
puts "Items with embeddings: #{SearchableItem.with_embedding.count}"

# Test search
search_service = Search::VectorSearchService.new
query = "yoga and meditation"

puts "\nSearching for: '#{query}'"
result = search_service.search(
  query: query,
  year: 2024,
  limit: 5
)

if result[:results].any?
  puts "\nFound #{result[:results].count} results:"
  result[:results].each_with_index do |item, i|
    puts "#{i+1}. #{item[:name]} (#{item[:type]}) - Score: #{item[:similarity_score]}"
    puts "   #{item[:description]&.truncate(100)}"
  end
else
  puts "\nNo results found or error: #{result[:error]}"
end

puts "\nExecution time: #{result[:execution_time]}ms"