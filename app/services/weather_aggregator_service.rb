# frozen_string_literal: true

# WeatherAggregatorService orchestrates multiple weather data sources
# with automatic failover and caching capabilities.
#
# Usage:
#   service = WeatherAggregatorService.new(latitude, longitude)
#   weather_data = service.fetch_weather
#
# Response format:
#   {
#     success: true,
#     source: 'openweather' | 'apple',
#     data: {
#       current_weather: { temperature, humidity, wind_speed, etc. },
#       forecast_daily: [ { date, temperature_max/min, condition, etc. } ],
#       metadata: { latitude, longitude, timezone, units }
#     },
#     cache_info: { from_cache, cached_at, expires_at }
#   }
#
class WeatherAggregatorService
  attr_reader :latitude, :longitude, :cache_service

  def initialize(latitude, longitude)
    @latitude = latitude
    @longitude = longitude
    @cache_service = WeatherCacheService.new(latitude, longitude)
  end

  def fetch_weather
    Rails.logger.info "WeatherAggregator: Fetching weather for #{@latitude}, #{@longitude}"

    # Try cache first
    cached_data = cache_service.fetch
    return cached_data if cached_data

    # Try primary source: OpenWeatherMap
    weather_data = fetch_from_openweather
    
    # If OpenWeather fails, try Apple Weather as fallback
    if !weather_data[:success]
      Rails.logger.warn "OpenWeather failed, falling back to Apple Weather"
      weather_data = fetch_from_apple_weather
    end

    # Cache successful responses
    if weather_data[:success]
      cache_service.store(weather_data)
    else
      # If all APIs fail, try to return stale cached data if available
      Rails.logger.error "All weather APIs failed, attempting to return stale cache"
      stale_data = fetch_stale_cache
      if stale_data
        Rails.logger.warn "Returning stale cached weather data"
        return stale_data
      else
        Rails.logger.error "No stale cache available, all weather sources exhausted"
      end
    end

    weather_data
  end

  def clear_cache
    cache_service.clear
  end

  private

  def fetch_from_openweather
    Rails.logger.info "Fetching from OpenWeatherMap"
    
    begin
      service = OpenWeatherService.new(@latitude, @longitude)
      result = service.fetch_weather_data
      
      if result[:success]
        Rails.logger.info "Successfully fetched weather from OpenWeatherMap"
      else
        Rails.logger.warn "OpenWeatherMap returned error: #{result[:error]}"
      end
      
      result
    rescue StandardError => e
      Rails.logger.error "OpenWeatherMap exception: #{e.message}"
      { success: false, source: 'openweather', error: e.message }
    end
  end

  def fetch_from_apple_weather
    Rails.logger.info "Fetching from Apple Weather"
    
    begin
      service = AppleWeather.new(@latitude, @longitude)
      response = service.fetch_weather_data
      
      if response.success?
        Rails.logger.info "Successfully fetched weather from Apple Weather"
        format_apple_weather_response(response.parsed_response)
      else
        Rails.logger.warn "Apple Weather returned error: #{response.code}"
        { success: false, source: 'apple', error: "Apple Weather API error: #{response.code}" }
      end
    rescue StandardError => e
      Rails.logger.error "Apple Weather exception: #{e.message}"
      { success: false, source: 'apple', error: e.message }
    end
  end

  def format_apple_weather_response(data)
    {
      success: true,
      source: 'apple',
      data: {
        current_weather: format_apple_current_weather(data['currentWeather']),
        forecast_daily: format_apple_daily_forecast(data['forecastDaily']),
        metadata: {
          latitude: @latitude,
          longitude: @longitude,
          timezone: data.dig('currentWeather', 'metadata', 'timezone'),
          units: 'imperial'
        }
      }
    }
  end

  def format_apple_current_weather(current)
    return {} unless current

    {
      temperature: celsius_to_fahrenheit(current['temperature']),
      feels_like: celsius_to_fahrenheit(current['temperatureApparent']),
      humidity: (current['humidity'] * 100).round,
      pressure: current['pressure'],
      visibility: meters_to_miles(current['visibility']),
      wind_speed: kmh_to_mph(current['windSpeed']),
      wind_direction: current['windDirection'],
      condition: map_apple_condition(current['conditionCode']),
      condition_description: current['conditionCode'],
      icon: current['conditionCode'],
      timestamp: current['asOf']
    }
  end

  def format_apple_daily_forecast(forecast)
    return [] unless forecast && forecast['days']

    forecast['days'].map do |day|
      {
        date: day['forecastStart'],
        temperature_max: celsius_to_fahrenheit(day['temperatureMax']),
        temperature_min: celsius_to_fahrenheit(day['temperatureMin']),
        condition: map_apple_condition(day['conditionCode']),
        condition_description: day['conditionCode'],
        precipitation_probability: day['precipitationChance'],
        humidity: (day.dig('daytimeForecast', 'humidity') || 0) * 100,
        # Extract twilight times from Apple Weather (using correct field names)
        sunrise: day['sunrise'],
        sunset: day['sunset'],
        civil_twilight_start: day['sunriseCivil'],
        civil_twilight_end: day['sunsetCivil'],
        nautical_twilight_start: day['sunriseNautical'],
        nautical_twilight_end: day['sunsetNautical'],
        astronomical_twilight_start: day['sunriseAstronomical'],
        astronomical_twilight_end: day['sunsetAstronomical']
      }
    end
  end

  def fetch_stale_cache
    # Try to get any cached data, even if expired
    # This requires direct cache access, which might not be available in all cache stores
    Rails.logger.warn "Attempting to retrieve stale cache data"
    
    # For now, return nil as we can't reliably get expired cache
    # In production, you might want to implement a secondary cache strategy
    nil
  end

  # Unit conversion helpers
  def celsius_to_fahrenheit(celsius)
    return nil unless celsius
    (celsius * 9.0 / 5.0 + 32).round(1)
  end

  def kmh_to_mph(kmh)
    return nil unless kmh
    (kmh * 0.621371).round(1)
  end

  def meters_to_miles(meters)
    return nil unless meters
    (meters * 0.000621371).round(1)
  end

  # Map Apple Weather condition codes to standard conditions
  def map_apple_condition(condition_code)
    case condition_code
    when 'Clear', 'MostlyClear'
      'Clear'
    when 'PartlyCloudy', 'MostlyCloudy', 'Cloudy'
      'Clouds'
    when 'Drizzle', 'Rain', 'HeavyRain', 'IsolatedThunderstorms', 'ScatteredThunderstorms', 'StrongStorms'
      'Rain'
    when 'Flurries', 'Snow', 'HeavySnow', 'Blizzard'
      'Snow'
    when 'Haze', 'Smoky'
      'Haze'
    when 'Foggy'
      'Fog'
    else
      condition_code
    end
  end
end