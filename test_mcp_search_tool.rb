#!/usr/bin/env ruby
require_relative 'config/environment'

puts "Testing MCP SearchTool..."
puts "=" * 60

# Test with year in query
query = "Temple 2017"
puts "\nSearching for: #{query}"

results = Mcp::SearchTool.call(query: query)

puts "\nResults:"
puts "Total results: #{results[:total_results]}"
puts "Query: #{results[:query]}"

if results[:results]&.any?
  results[:results].first(3).each do |result|
    puts "\n- #{result[:title]}"
    puts "  URL: #{result[:url]}"
    puts "  Metadata: #{result[:metadata].inspect}"
  end
else
  puts "No results found"
  puts "Error: #{results[:error]}" if results[:error]
end

# Test year extraction
["2017 temple", "temple burn 2018", "2019 art", "man burn"].each do |test_query|
  year_match = test_query.match(/(19\d{2}|20\d{2})/)
  extracted_year = year_match ? year_match[1].to_i : nil
  puts "\nQuery: '#{test_query}' => Year: #{extracted_year || 'all years'}"
end