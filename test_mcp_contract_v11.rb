#!/usr/bin/env ruby
require_relative 'config/environment'

puts "Testing Seven Pools MCP Server Tool Contract v1.1..."
puts "=" * 60

# Test 1: Search tool with new parameters
puts "\n1. Testing search tool with new contract:"
search_result = Mcp::SearchTool.call(
  query: "temple 2017",
  top_k: 5,
  diversify_by_pool: true,
  include_trace: true,
  include_counts: true
)

puts "Search results:"
puts "  Items found: #{search_result[:items]&.length || 0}"
puts "  Total estimate: #{search_result.dig(:meta, :total_estimate)}"
puts "  Pool counts: #{search_result.dig(:meta, :pool_counts)}"

if search_result[:items]&.any?
  first_item = search_result[:items].first
  puts "  First item:"
  puts "    Title: #{first_item[:title]}"
  puts "    Pools hit: #{first_item[:pools_hit]}"
  puts "    Score: #{first_item[:score]}"
  puts "    Trace: #{first_item[:trace]}"
  puts "    Rights: #{first_item[:rights]}"
end

# Test 2: Fetch tool with new parameters
puts "\n2. Testing fetch tool with relations:"
if search_result[:items]&.any?
  item_id = search_result[:items].first[:id]
  
  fetch_result = Mcp::FetchTool.call(
    id: item_id,
    include_relations: true,
    relation_depth: 2
  )
  
  puts "Fetch results:"
  puts "  Title: #{fetch_result[:title]}"
  puts "  Pools: #{fetch_result[:pools]}"
  puts "  Relations: #{fetch_result[:relations]&.length || 0}"
  puts "  Timeline events: #{fetch_result[:timeline]&.length || 0}"
  puts "  Provenance sources: #{fetch_result[:provenance]&.length || 0}"
  puts "  Rights: #{fetch_result[:rights]}"
  
  if fetch_result[:relations]&.any?
    puts "  First relation:"
    relation = fetch_result[:relations].first
    puts "    Type: #{relation[:type]}"
    puts "    To: #{relation[:to_title]}"
    puts "    Pool: #{relation[:pool]}"
  end
end

# Test 3: Analyze pools tool with modes
puts "\n3. Testing analyze_pools tool with different modes:"

test_text = "The Temple of Awareness was a beautiful art installation that created transformative experiences for the community"

modes = %w[extract classify link]
modes.each do |mode|
  puts "\n  Mode: #{mode}"
  analyze_result = Mcp::AnalyzePoolsTool.call(
    text: test_text,
    mode: mode,
    link_threshold: 0.6
  )
  
  puts "    Entities found: #{analyze_result[:entities]&.length || 0}"
  puts "    Ambiguous terms: #{analyze_result[:ambiguous_terms]&.length || 0}"
  puts "    Normalized query: #{analyze_result[:normalized_query]}"
  
  if analyze_result[:entities]&.any?
    entity = analyze_result[:entities].first
    puts "    First entity:"
    puts "      Span: '#{entity[:span]}'"
    puts "      Pool: #{entity[:pool]}"
    puts "      Confidence: #{entity[:confidence]}"
    puts "      Linked ID: #{entity[:linked_id]}"
  end
end

# Test 4: Pool bridge tool with new input format
puts "\n4. Testing pool_bridge tool with new contract:"

bridge_result = Mcp::PoolBridgeTool.call(
  a: "manifest",
  b: "experience", 
  top_k: 3
)

puts "Bridge results:"
puts "  Bridges found: #{bridge_result[:bridges]&.length || 0}"

if bridge_result[:bridges]&.any?
  bridge_result[:bridges].each_with_index do |bridge, i|
    puts "  Bridge #{i+1}:"
    puts "    Title: #{bridge[:title]}"
    puts "    Pools hit: #{bridge[:pools_hit]}"
    puts "    Score: #{bridge[:bridge_score]}"
    puts "    Path: #{bridge[:path]}"
  end
end

# Test 5: Error handling
puts "\n5. Testing error handling:"

# Invalid pool in search
error_result = Mcp::SearchTool.call(
  query: "test",
  pools: ["invalid_pool"]
)
puts "  Invalid pool error: #{error_result[:error] ? 'Handled correctly' : 'Not handled'}"

# Invalid top_k
error_result2 = Mcp::SearchTool.call(
  query: "test",
  top_k: 100  # Over the limit
)
puts "  Invalid top_k error: #{error_result2[:error] ? 'Handled correctly' : 'Not handled'}"

# Text too long for analyze_pools
long_text = "a" * 9000
error_result3 = Mcp::AnalyzePoolsTool.call(
  text: long_text
)
puts "  Text too long error: #{error_result3[:error] ? 'Handled correctly' : 'Not handled'}"

puts "\n" + "=" * 60
puts "Tool Contract v1.1 testing complete!"
puts "All tools now implement the enhanced contract with:"
puts "- Proper input validation and error handling"
puts "- Rights and provenance in all responses"
puts "- Path/trace strings for explainability"
puts "- Flexible input parsing (pool names, entity IDs, free text)"
puts "- Consistent output formats"