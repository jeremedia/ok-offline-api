#!/usr/bin/env ruby
require_relative 'config/environment'

# Test basic search for temple
puts "Testing search for 2017 temple..."
puts "=" * 60

# Check if any temple items exist
temple_count = SearchableItem.where("name ILIKE ?", "%temple%").count
puts "Total temple items in database: #{temple_count}"

# Check 2017 specifically
temple_2017 = SearchableItem.where("name ILIKE ?", "%temple%").where(year: 2017).first(5)
puts "\n2017 Temple items:"
temple_2017.each do |item|
  puts "- #{item.name} (#{item.item_type})"
end

# Test unified search
puts "\nTesting UnifiedSearchService..."
service = Search::UnifiedSearchService.new
# Try searching without year restriction first
results = service.search(
  query: "temple",
  year: nil,  # Search all years
  limit: 10
)

puts "\nSearch results:"
if results[:results].any?
  results[:results].each do |result|
    puts "- #{result[:name]} (#{result[:year]}, #{result[:item_type]})"
  end
else
  puts "No results found"
  puts "Error: #{results[:error]}" if results[:error]
end

# Check if embeddings exist
embedded_count = SearchableItem.where.not(embedding: nil).count
puts "\nItems with embeddings: #{embedded_count}"