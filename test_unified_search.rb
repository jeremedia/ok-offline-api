#!/usr/bin/env ruby
require 'net/http'
require 'json'
require 'uri'

# Test the unified search endpoint
def test_unified_search(query, expand_graph: true, graph_depth: 1)
  uri = URI('http://localhost:3555/api/v1/search/unified')
  
  request = Net::HTTP::Post.new(uri)
  request['Content-Type'] = 'application/json'
  
  request.body = {
    query: query,
    year: 2025,
    limit: 10,
    expand_graph: expand_graph,
    graph_depth: graph_depth
  }.to_json
  
  response = Net::HTTP.start(uri.hostname, uri.port) do |http|
    http.request(request)
  end
  
  result = JSON.parse(response.body)
  
  puts "\n" + "="*60
  puts "UNIFIED SEARCH: #{query}"
  puts "="*60
  
  if result['error']
    puts "ERROR: #{result['error']}"
    return
  end
  
  # Debug: show the structure
  puts "\nDebug - Result keys: #{result.keys}"
  puts "Debug - First result keys: #{result['results'].first.keys if result['results'].any?}"
  
  puts "Total results: #{result['meta']['total_count']}"
  puts "Execution time: #{result['meta']['execution_time']}s"
  puts "Query entities: #{result['query_entities']}"
  puts "Graph expansions: #{result['graph_expansion_count']}"
  
  puts "\nResults:"
  puts "Raw result data: #{result.inspect}" if result['results'].empty?
  
  result['results'].each_with_index do |item, i|
    puts "\n#{i+1}. #{item['name']} (#{item['type'] || item['item_type']}, #{item['year']})"
    puts "   Location: #{item['location_string']}" if item['location_string'] && !item['location_string'].empty?
    puts "   Scores: Vector=#{item['similarity_score']}, Graph=#{item['graph_score']}, Combined=#{item['combined_score']}"
    
    if item['graph_expansion']
      puts "   ⚡ Graph expansion: #{item['expansion_reason']}"
    end
    
    if item['entity_connections']
      connections = item['entity_connections']
      puts "   Entities: #{connections['total_entities']}"
      connections['connections'].each do |conn|
        puts "     - #{conn['type']}: #{conn['entity']} (#{conn['connected_items']} items, #{conn['related_entities']} related)"
      end
    end
  end
end

# Test queries
puts "Testing unified search with graph expansion..."

# Test 1: OKNOTOK search
test_unified_search("OKNOTOK")

# Test 2: Search by theme
test_unified_search("yin and yang", graph_depth: 2)

# Test 3: Search by activity
test_unified_search("edge play")

# Test 4: Without graph expansion (pure vector search)
test_unified_search("OKNOTOK", expand_graph: false)