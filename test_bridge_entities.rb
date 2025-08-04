#!/usr/bin/env ruby
# Test script for bridge entities endpoint

require 'net/http'
require 'json'
require 'uri'

def test_bridge_entities_endpoint
  base_url = "http://localhost:3555"
  
  puts "Testing Bridge Entities Endpoint"
  puts "=" * 40
  
  # Test cases
  test_cases = [
    { params: "limit=3", description: "Top 3 bridge entities" },
    { params: "min_pools=4&limit=5", description: "Entities spanning 4+ pools" },
    { params: "min_pools=2&limit=10", description: "Default query with larger limit" }
  ]
  
  test_cases.each_with_index do |test_case, i|
    puts "\n#{i + 1}. #{test_case[:description]}"
    puts "-" * 30
    
    uri = URI("#{base_url}/api/v1/graph/bridge_entities?#{test_case[:params]}")
    
    begin
      response = Net::HTTP.get_response(uri)
      
      if response.code == '200'
        data = JSON.parse(response.body)
        puts "✓ Success! Found #{data['total_bridges']} bridge entities"
        
        # Show top result details
        if data['bridge_entities'].any?
          top_entity = data['bridge_entities'].first
          puts "  Top result: '#{top_entity['name']}'"
          puts "  - Spans #{top_entity['pool_count']} pools: #{top_entity['pools'].join(', ')}"
          puts "  - Total frequency: #{top_entity['total_frequency']}"
          puts "  - Bridge power: #{top_entity['bridge_power']}"
        end
      else
        puts "✗ Error: #{response.code} - #{response.body}"
      end
      
    rescue => e
      puts "✗ Connection error: #{e.message}"
      puts "  Make sure Rails server is running on port 3555"
    end
  end
  
  puts "\n" + "=" * 40
  puts "Bridge Power Formula: Pool_Count × √Total_Frequency × Cross_Pool_Centrality"
  puts "Higher bridge power = stronger connection across knowledge pools"
end

if __FILE__ == $0
  test_bridge_entities_endpoint
end