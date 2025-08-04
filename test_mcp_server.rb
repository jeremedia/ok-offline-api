#!/usr/bin/env ruby

require 'net/http'
require 'json'

# Test the MCP server with different tools
class McpTester
  def initialize(base_url = 'http://localhost:3555')
    @base_url = base_url
  end
  
  def test_capabilities
    puts "🔧 Testing MCP Server Capabilities..."
    
    response = make_request('POST', '/api/v1/mcp/tools', {
      method: 'tools/list'
    })
    
    if response['result']
      puts "✅ Capabilities endpoint working!"
      puts "Available tools: #{response.dig('result', 'capabilities', 'tools')&.keys}"
    else
      puts "❌ Capabilities test failed: #{response}"
    end
    
    puts ""
  end
  
  def test_search
    puts "🔍 Testing Search Tool..."
    
    queries = [
      "OKNOTOK",
      "temple experience", 
      "fire spinning community",
      "radical self reliance"
    ]
    
    queries.each do |query|
      puts "  Query: '#{query}'"
      
      response = make_request('POST', '/api/v1/mcp/tools', {
        method: 'tools/call',
        params: {
          name: 'search',
          arguments: { query: query }
        }
      })
      
      if response['result']
        content = JSON.parse(response.dig('result', 'content', 0, 'text'))
        puts "    ✅ Found #{content['total_results']} results"
        puts "    📊 Vector: #{content.dig('search_metadata', 'vector_results')}, Graph: #{content.dig('search_metadata', 'graph_expansions')}"
      else
        puts "    ❌ Search failed: #{response['error']}"
      end
    end
    
    puts ""
  end
  
  def test_fetch
    puts "📄 Testing Fetch Tool..."
    
    # Get an item ID from search first
    search_response = make_request('POST', '/api/v1/mcp/tools', {
      method: 'tools/call', 
      params: {
        name: 'search',
        arguments: { query: "OKNOTOK" }
      }
    })
    
    if search_response['result']
      content = JSON.parse(search_response.dig('result', 'content', 0, 'text'))
      first_result = content['results']&.first
      
      if first_result
        item_id = first_result['id']
        puts "  Fetching item ID: #{item_id}"
        
        response = make_request('POST', '/api/v1/mcp/tools', {
          method: 'tools/call',
          params: {
            name: 'fetch', 
            arguments: { id: item_id }
          }
        })
        
        if response['result']
          content = JSON.parse(response.dig('result', 'content', 0, 'text'))
          puts "    ✅ Fetched: #{content['title']}"
          puts "    🧠 Enliteracy score: #{content.dig('enliteracy_score', 'overall_score')}"
          puts "    🌊 Pools: #{content['pools']&.keys}"
        else
          puts "    ❌ Fetch failed: #{response['error']}"
        end
      end
    end
    
    puts ""
  end
  
  def test_analyze_pools
    puts "🧪 Testing Pool Analysis Tool..."
    
    test_texts = [
      "Our solar-powered camp offers daily meditation sessions and community dinners. We believe in radical inclusion and gift economy principles.",
      "The temple stands at the heart of Black Rock City, a sacred space for reflection, grief, and transformation. Built from reclaimed wood.",
      "Fire spinning workshop every Tuesday at sunset. Learn poi, staff, and safety techniques from experienced performers."
    ]
    
    test_texts.each_with_index do |text, i|
      puts "  Text #{i+1}: #{text[0..60]}..."
      
      response = make_request('POST', '/api/v1/mcp/tools', {
        method: 'tools/call',
        params: {
          name: 'analyze_pools',
          arguments: { text: text }
        }
      })
      
      if response['result']
        content = JSON.parse(response.dig('result', 'content', 0, 'text'))
        richness = content.dig('analysis', 'semantic_richness', 'richness_score')
        domains = content.dig('analysis', 'cultural_domains')
        puts "    ✅ Richness: #{richness}, Domains: #{domains&.count}"
      else
        puts "    ❌ Analysis failed: #{response['error']}"
      end
    end
    
    puts ""
  end
  
  def test_pool_bridge
    puts "🌉 Testing Pool Bridge Tool..."
    
    bridge_tests = [
      ["manifest", "experience"],
      ["idea", "practical"], 
      ["relational", "emanation"]
    ]
    
    bridge_tests.each do |pool1, pool2|
      puts "  Bridge: #{pool1} ↔ #{pool2}"
      
      response = make_request('POST', '/api/v1/mcp/tools', {
        method: 'tools/call',
        params: {
          name: 'pool_bridge',
          arguments: { pool1: pool1, pool2: pool2 }
        }
      })
      
      if response['result']
        content = JSON.parse(response.dig('result', 'content', 0, 'text'))
        entities = content['bridge_entities']&.count || 0
        items = content['bridge_items']&.count || 0
        puts "    ✅ Found #{entities} bridge entities, #{items} bridge items"
      else
        puts "    ❌ Bridge analysis failed: #{response['error']}"
      end
    end
    
    puts ""
  end
  
  def run_all_tests
    puts "🚀 MCP Server Test Suite"
    puts "=" * 50
    
    test_capabilities
    test_search
    test_fetch
    test_analyze_pools
    test_pool_bridge
    
    puts "✅ All tests completed!"
  end
  
  private
  
  def make_request(method, path, body = nil)
    uri = URI("#{@base_url}#{path}")
    
    http = Net::HTTP.new(uri.host, uri.port)
    request = case method
              when 'GET'
                Net::HTTP::Get.new(uri)
              when 'POST'
                Net::HTTP::Post.new(uri)
              end
    
    request['Content-Type'] = 'application/json'
    request.body = body.to_json if body
    
    response = http.request(request)
    JSON.parse(response.body)
  rescue => e
    { 'error' => e.message }
  end
end

# Run the tests if script is executed directly
if __FILE__ == $0
  tester = McpTester.new
  tester.run_all_tests
end