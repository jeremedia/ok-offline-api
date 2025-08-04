#!/usr/bin/env ruby

puts "Setting up Neo4j connection..."

# First try to connect with default password
require 'net/http'
require 'json'

uri = URI('http://localhost:7474/db/neo4j/tx/commit')
req = Net::HTTP::Post.new(uri)
req.basic_auth('neo4j', 'neo4j')
req['Content-Type'] = 'application/json'
req.body = { statements: [{ statement: "RETURN 1 as test" }] }.to_json

res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }

if res.code == '200'
  puts "Connected with default password 'neo4j'"
  puts "You should change the password for security"
else
  # Try with password123
  req.basic_auth('neo4j', 'password123')
  res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }
  
  if res.code == '200'
    puts "Connected with password 'password123'"
  else
    puts "Failed to connect. Response: #{res.code} - #{res.body}"
    puts "\nPlease set your Neo4j password:"
    puts "1. Open http://localhost:7474 in your browser"
    puts "2. Login with username: neo4j"
    puts "3. Set password to: password123"
    puts "4. Or update NEO4J_PASSWORD in .env"
  end
end