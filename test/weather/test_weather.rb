# Test script for weather aggregation services
# Run with: rails runner test_weather.rb

puts "Testing Weather Aggregation Services\n"
puts "=" * 50

# Test coordinates (Monterey, CA)
latitude = "36.598341500150156"
longitude = "-121.8744153547224"

puts "\nTesting WeatherAggregatorService"
puts "Coordinates: #{latitude}, #{longitude}"

# Test the aggregator service
aggregator = WeatherAggregatorService.new(latitude, longitude)
result = aggregator.fetch_weather

if result[:success]
  puts "\n✓ Successfully fetched weather data"
  puts "  Source: #{result[:source]}"
  puts "  Current Temperature: #{result.dig(:data, :current_weather, :temperature)}°F"
  puts "  Condition: #{result.dig(:data, :current_weather, :condition)}"
  puts "  Humidity: #{result.dig(:data, :current_weather, :humidity)}%"
  puts "  Wind Speed: #{result.dig(:data, :current_weather, :wind_speed)} mph"
  
  if result[:cache_info]
    puts "\n  Cache Info:"
    puts "    From Cache: #{result.dig(:cache_info, :from_cache)}"
    puts "    Cached At: #{result.dig(:cache_info, :cached_at)}"
    puts "    Expires At: #{result.dig(:cache_info, :expires_at)}"
  end
  
  if result.dig(:data, :forecast_daily).is_a?(Array) && result.dig(:data, :forecast_daily).any?
    puts "\n  Daily Forecast (next 3 days):"
    result.dig(:data, :forecast_daily).take(3).each do |day|
      puts "    #{day[:date]}: #{day[:temperature_min]}°F - #{day[:temperature_max]}°F, #{day[:condition]}"
    end
  end
else
  puts "\n✗ Failed to fetch weather data"
  puts "  Error: #{result[:error]}"
end

# Test cache
puts "\n\nTesting Cache Service"
puts "-" * 30

# Fetch again to test cache hit
result2 = aggregator.fetch_weather
if result2[:success] && result2.dig(:cache_info, :from_cache)
  puts "✓ Cache hit successful"
else
  puts "✗ Cache hit failed"
end

# Clear cache
aggregator.clear_cache
puts "✓ Cache cleared"

puts "\n\nAPI Key Status:"
puts "-" * 30
puts "OpenWeather API Key: #{ENV['OPENWEATHER_API_KEY'].present? ? '✓ Set' : '✗ Not set'}"
puts "Apple Weather Key ID: #{ENV['APPLE_WEATHER_KEY_ID'].present? ? '✓ Set' : '✗ Not set'}"
puts "Apple Weather Team ID: #{ENV['APPLE_WEATHER_TEAM_ID'].present? ? '✓ Set' : '✗ Not set'}"
puts "Apple Weather Service ID: #{ENV['APPLE_WEATHER_SERVICE_ID'].present? ? '✓ Set' : '✗ Not set'}"
puts "Apple Weather Private Key Path: #{ENV['APPLE_WEATHER_PRIVATE_KEY_PATH'].present? ? '✓ Set' : '✗ Not set'}"

puts "\n" + "=" * 50