#!/usr/bin/env ruby
require_relative 'config/environment'

puts "Testing MCP search with fixed approach..."
puts "=" * 60

# Test the MCP search tool
query = "Temple 2017"
puts "\nSearching for: '#{query}'"

results = Mcp::SearchTool.call(query: query)

puts "\nMCP Search Results:"
puts "Total results: #{results[:total_results]}"
puts "Search metadata: #{results[:search_metadata]}"

if results[:results]&.any?
  results[:results].first(5).each_with_index do |result, i|
    puts "\n#{i+1}. #{result[:title]}"
    puts "   URL: #{result[:url]}"
    puts "   Type: #{result[:metadata][:item_type]}"
    puts "   Year: #{result[:metadata][:year]}"
    puts "   Scores: #{result[:metadata][:search_score]}"
  end
else
  puts "No results found"
  puts "Error: #{results[:error]}" if results[:error]
end

# Let's also test with just "temple" to see what happens
puts "\n\n" + "="*60
puts "Testing with just 'temple' (no year):"
results2 = Mcp::SearchTool.call(query: "temple")
puts "Total results: #{results2[:total_results]}"
if results2[:results]&.any?
  results2[:results].first(3).each do |r|
    puts "- #{r[:title]} (#{r[:metadata][:year]})"
  end
end