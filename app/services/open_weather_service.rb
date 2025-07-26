# frozen_string_literal: true

require 'httparty'

class OpenWeatherService
  include HTTParty
  base_uri 'https://api.openweathermap.org/data/2.5'

  UNITS = 'imperial' # Use imperial units for US (Fahrenheit, mph)

  def initialize(latitude, longitude)
    @latitude = latitude
    @longitude = longitude
    @api_key = ENV['OPENWEATHER_API_KEY']
  end

  def fetch_weather_data
    return error_response('OpenWeather API key not configured') if @api_key.blank?

    begin
      current_weather = fetch_current_weather
      forecast = fetch_forecast

      return current_weather unless current_weather[:success]
      return forecast unless forecast[:success]

      format_response(current_weather[:data], forecast[:data])
    rescue StandardError => e
      Rails.logger.error "OpenWeatherService error: #{e.message}"
      error_response("Failed to fetch weather data: #{e.message}")
    end
  end

  private

  def fetch_current_weather
    response = self.class.get('/weather', query: weather_params)
    
    if response.success?
      { success: true, data: response.parsed_response }
    else
      { success: false, error: "Current weather request failed: #{response.code}" }
    end
  end

  def fetch_forecast
    response = self.class.get('/forecast', query: weather_params.merge(cnt: 40)) # 5 days
    
    if response.success?
      { success: true, data: response.parsed_response }
    else
      { success: false, error: "Forecast request failed: #{response.code}" }
    end
  end

  def weather_params
    {
      lat: @latitude,
      lon: @longitude,
      appid: @api_key,
      units: UNITS
    }
  end

  def format_response(current, forecast)
    {
      success: true,
      source: 'openweather',
      data: {
        current_weather: format_current_weather(current),
        forecast_daily: format_daily_forecast(forecast),
        metadata: {
          latitude: @latitude,
          longitude: @longitude,
          timezone: current['timezone'],
          units: UNITS
        }
      }
    }
  end

  def format_current_weather(data)
    {
      temperature: data.dig('main', 'temp'),
      feels_like: data.dig('main', 'feels_like'),
      humidity: data.dig('main', 'humidity'),
      pressure: data.dig('main', 'pressure'),
      visibility: meters_to_miles(data['visibility']),
      wind_speed: data.dig('wind', 'speed'),
      wind_direction: data.dig('wind', 'deg'),
      condition: data.dig('weather', 0, 'main'),
      condition_description: data.dig('weather', 0, 'description'),
      icon: data.dig('weather', 0, 'icon'),
      timestamp: Time.at(data['dt']).iso8601
    }
  end

  def format_daily_forecast(data)
    return [] unless data['list']

    # Group forecast by day (OpenWeather provides 3-hour intervals)
    daily_groups = data['list'].group_by do |item|
      Time.at(item['dt']).to_date
    end

    daily_groups.map do |date, items|
      temps = items.map { |item| item.dig('main', 'temp') }.compact
      {
        date: date.iso8601,
        temperature_max: temps.max,
        temperature_min: temps.min,
        condition: items.first.dig('weather', 0, 'main'),
        condition_description: items.first.dig('weather', 0, 'description'),
        precipitation_probability: items.map { |item| (item['pop'] || 0) * 100 }.max.to_i,
        humidity: items.map { |item| item.dig('main', 'humidity') }.compact.sum / items.size
      }
    end.take(10) # Limit to 10 days like Apple Weather
  end

  def error_response(message)
    {
      success: false,
      source: 'openweather',
      error: message
    }
  end

  def meters_to_miles(meters)
    return nil unless meters
    (meters * 0.000621371).round(1)
  end
end