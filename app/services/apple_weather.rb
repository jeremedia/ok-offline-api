# frozen_string_literal: true

require 'httparty'
require 'openssl'
require 'jwt'

class AppleWeather
  include HTTParty
  base_uri 'https://weatherkit.apple.com/api/v1'
  TIMEZONE = "America/Los_Angeles"

  #GET https://weatherkit.apple.com/api/v1/availability/{latitude}/{longitude}
  # curl -v -H 'Authorization: Bearer [developer token]' "https://weatherkit.apple.com/api/v1/availability/37.323/122.032?country=US"
  def initialize(latitude = "36.598341500150156", longitude = "-121.8744153547224", language = 'en')

    #coordinates = geocode(location)
    #latitude = coordinates[0]
    #longitude = coordinates[1]

    #"36.598341500150156, -121.8744153547224"
    #ap coordinates
    @language = language
    @latitude = latitude
    @longitude = longitude

    @options = {
      query: {
        # currentAsOf date-time
        # The time to obtain current conditions. Defaults to now.

        # dailyEnd date-time
        # The time to end the daily forecast. If this parameter is absent, daily forecasts run for 10 days.

        # dailyStart date-time
        # The time to start the daily forecast. If this parameter is absent, daily forecasts start on the current day.

        # dataSets [DataSet]
        # A comma-delimited list of data sets to include in the response.
        dataSets: "currentWeather,forecastDaily",

        # hourlyEnd date-time
        # The time to end the hourly forecast. If this parameter is absent, hourly forecasts run 24 hours or the length of the daily forecast, whichever is longer.

        # hourlyStart date-time
        # The time to start the hourly forecast. If this parameter is absent, hourly forecasts start on the current hour.

        # timezone string
        # (Required) The name of the timezone to use for rolling up weather forecasts into daily forecasts.
        timezone: TIMEZONE,
      },
      headers: headers
    }

  end

  def geocode(location)
    result = Geocoder.search(location).first
    result.coordinates
  end

  def fetch_weather_data
    Rails.logger.info "AppleWeather: Fetching weather for #{@latitude}, #{@longitude}"
    response = self.class.get("/weather/#{@language}/#{@latitude}/#{@longitude}", @options)
    
    if response.success?
      Rails.logger.info "AppleWeather: Successfully fetched weather data"
    else
      Rails.logger.error "AppleWeather: Failed with status #{response.code}"
    end
    
    response
  end

  #private

  def headers
    {
      'Authorization' => "Bearer #{jwt_token}",
      'Content-Type' => 'application/json'
    }
  end

  def load_key
    key_path = ENV['APPLE_WEATHER_PRIVATE_KEY_PATH'] || "app/services/apple_key"
    File.read(key_path)
  end
  def jwt_token
    team_id = ENV['APPLE_WEATHER_TEAM_ID'] || '7SWYPA4YZ5'
    service_id = ENV['APPLE_WEATHER_SERVICE_ID'] || 'com.zinod.slackbot'
    api_key = ENV['APPLE_WEATHER_KEY_ID'] || '9XG6YW4RKV'
    private_key_content = load_key
    private_key = OpenSSL::PKey::EC.new(private_key_content)
    now = Time.now.to_i
    exp = now + 3600

    headers = {
      'alg' => 'ES256',
      'kid' => api_key,
      'id' => "#{team_id}.#{service_id}"
    }

    payload = {
      'iss' => team_id,
      'iat' => now,
      'exp' => exp,
      'sub' => service_id
    }

    JWT.encode(payload, private_key, 'ES256', headers)
  end

end

#     api_key = "XG6YW4RKV.com.zinod.slackbot"
#team_id: 7SWYPA4YZ5
# Name:WeatherBot
# Key ID:9XG6YW4RKV
# Services:WeatherKit
