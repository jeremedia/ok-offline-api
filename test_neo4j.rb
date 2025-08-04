#!/usr/bin/env ruby
require 'bundler/setup'
require 'neo4j_ruby_driver'

puts "Testing Neo4j connection..."

passwords = ['password', 'neo4j', 'neo', '']

passwords.each do |pwd|
  begin
    driver = Neo4j::Driver::GraphDatabase.driver(
      'bolt://127.0.0.1:7687',
      Neo4j::Driver::AuthTokens.basic('neo4j', pwd),
      encryption: false
    )
    
    driver.session do |session|
      result = session.run("RETURN 1 as n")
      if result.single[:n] == 1
        puts "✓ SUCCESS! Connected with password: '#{pwd}'"
        puts "  Please update your .env file with: NEO4J_PASSWORD=#{pwd}"
        exit 0
      end
    end
    driver.close
  rescue => e
    puts "✗ Failed with password '#{pwd}': #{e.message}"
  end
end

puts "\nCould not connect with any of the tried passwords."
puts "You may need to:"
puts "1. Open http://localhost:7474 in a browser"
puts "2. Login with username: neo4j"
puts "3. Set a new password when prompted"
puts "4. Update the .env file with the new password"