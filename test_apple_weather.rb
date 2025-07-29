require 'dotenv/load'
require_relative 'config/environment'

apple_weather = AppleWeather.new
puts "Testing Apple Weather API with new key..."
puts "Team ID: #{ENV.fetch('APPLE_WEATHER_TEAM_ID')}"
puts "Service ID: #{ENV.fetch('APPLE_WEATHER_SERVICE_ID')}"
puts "Key ID: #{ENV.fetch('APPLE_WEATHER_KEY_ID')}"

begin
  response = apple_weather.fetch_weather_data
  
  if response.success?
    puts "\n✅ Success! Apple Weather API is working with the new key."
    puts "Response code: #{response.code}"
    puts "Response data sample: #{response.parsed_response.keys.first(5).join(', ')}..."
  else
    puts "\n❌ Error: API request failed"
    puts "Response code: #{response.code}"
    puts "Response message: #{response.message}"
    puts "Response body: #{response.body}"
  end
rescue => e
  puts "\n❌ Exception occurred: #{e.message}"
  puts e.backtrace.first(5)
end