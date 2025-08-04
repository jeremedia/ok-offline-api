#!/usr/bin/env ruby
require_relative 'config/environment'

puts "Testing OKNOTOK neighbors question via MCP..."
puts "=" * 60

# Test the location_neighbors tool directly
puts "\n1. Direct tool call:"
result = Mcp::LocationNeighborsTool.call(camp_name: 'OKNOTOK')

puts "Camp: #{result[:camp_name]}"
puts "Years analyzed: #{result[:years_analyzed].join(', ')}"
puts "Location stability: #{result[:location_patterns][:location_stability]}"
puts "Most frequent neighbor: #{result[:summary][:most_frequent_neighbor]}"

puts "\nRecurring neighbors across multiple years:"
result[:summary][:recurring_neighbors].each do |name, count|
  puts "  - #{name}: appeared #{count} times"
end

puts "\n2. Sample year analysis (2022):"
year_2022 = result[:neighbor_analysis].find { |ya| ya[:year] == 2022 }
if year_2022
  puts "Location: #{year_2022[:location]}"
  puts "Neighbors:"
  year_2022[:neighbors].each do |neighbor|
    puts "  - #{neighbor[:name]} at #{neighbor[:location]} (#{neighbor[:distance_description]})"
  end
end

puts "\n3. Testing different radius options:"
%w[immediate adjacent neighborhood].each do |radius|
  puts "\n#{radius.upcase} radius for 2024:"
  result_radius = Mcp::LocationNeighborsTool.call(
    camp_name: 'OKNOTOK', 
    year: 2024, 
    radius: radius
  )
  
  if result_radius[:neighbor_analysis]&.any?
    neighbors = result_radius[:neighbor_analysis].first[:neighbors]
    puts "  Found #{neighbors.length} neighbors"
    neighbors.first(3).each do |n|
      puts "    - #{n[:name]} (#{n[:distance_description]})"
    end
  end
end

puts "\n" + "=" * 60
puts "This tool would enable proper responses to questions like:"
puts '"Can you determine OKNOTOK\'s neighbors over the years?"'
puts ""
puts "Instead of returning generic search results about 'neighbors' and 'maps',"
puts "the agent would use the location_neighbors tool to provide:"
puts "- Actual adjacent camps by year"
puts "- Location patterns and stability analysis"
puts "- Recurring neighbor relationships"
puts "- Geographic proximity calculations"
puts "- Multi-year neighbor tracking"
puts ""
puts "The MCP server now has 5 specialized tools for comprehensive"
puts "Burning Man data analysis and enliteracy operations."