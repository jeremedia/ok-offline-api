require 'net/http'
require 'json'
require 'uri'

# Test the OpenGraph image generation endpoint
uri = URI('http://100.104.170.10:3555/api/v1/opengraph/generate')

# Test 1: Default title (should use "OK-OFFLINE")
puts "Test 1: Default title..."
response = Net::HTTP.post(uri, {}.to_json, 'Content-Type' => 'application/json')
puts "Status: #{response.code}"
puts "Response: #{response.body}"
puts

# Test 2: Custom title and subtitle
puts "Test 2: Custom title and subtitle..."
params = {
  title: "Burning Man 2025",
  subtitle: "Welcome Home to Black Rock City",
  year: 2025
}
response = Net::HTTP.post(uri, params.to_json, 'Content-Type' => 'application/json')
puts "Status: #{response.code}"
result = JSON.parse(response.body) rescue response.body
puts "Response: #{JSON.pretty_generate(result)}" rescue puts response.body

if result['success'] && result['url']
  puts "\nGenerated image URL: #{result['url']}"
  puts "You can view the image by opening this URL in a browser"
end