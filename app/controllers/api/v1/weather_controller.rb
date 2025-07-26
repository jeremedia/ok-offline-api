# frozen_string_literal: true

module Api
  module V1
    class WeatherController < BaseController
      before_action :validate_request_params, only: [:current]

def test
        render json: { message: 'Weather API is working' }
        end
      # POST /api/v1/weather/current
      def current
        weather_aggregator = WeatherAggregatorService.new(
          params[:latitude],
          params[:longitude]
        )
        
        weather_data = weather_aggregator.fetch_weather

        if weather_data[:success]
          render json: format_response(weather_data)
        else
          # Try to get cached data when service fails
          render json: error_response(weather_data[:error]), status: :service_unavailable
        end
      rescue StandardError => e
        Rails.logger.error "Weather API error: #{e.message}"
        render json: error_response('Internal server error'), status: :internal_server_error
      end

      private

      def validate_request_params
        # Check required parameters
        unless params[:latitude].present? && params[:longitude].present?
          render json: error_response('Missing required parameters: latitude and longitude'), 
                 status: :bad_request
          return
        end

        # Validate latitude and longitude ranges
        begin
          latitude = Float(params[:latitude])
          longitude = Float(params[:longitude])

          unless latitude.between?(-90, 90)
            render json: error_response('Invalid latitude. Must be between -90 and 90'), 
                   status: :bad_request
            return
          end

          unless longitude.between?(-180, 180)
            render json: error_response('Invalid longitude. Must be between -180 and 180'), 
                   status: :bad_request
            return
          end
        rescue ArgumentError
          render json: error_response('Invalid coordinate format. Please provide numeric values'), 
                 status: :bad_request
        end
      end

      def format_response(weather_data)
        # Extract the actual weather data from the aggregator response
        data = weather_data[:data] || {}
        
        # Format according to API spec
        {
          data: {
            temperature: data.dig(:current_weather, :temperature),
            windSpeed: data.dig(:current_weather, :wind_speed),
            windDirection: data.dig(:current_weather, :wind_direction),
            humidity: data.dig(:current_weather, :humidity),
            pressure: data.dig(:current_weather, :pressure),
            visibility: data.dig(:current_weather, :visibility),
            condition: data.dig(:current_weather, :condition),
            conditionDescription: data.dig(:current_weather, :condition_description),
            feelsLike: data.dig(:current_weather, :feels_like),
            dustLevel: calculate_dust_level(data[:current_weather]),
            moonPhase: calculate_moon_phase,
            forecast: format_forecast(data[:forecast_daily])
          },
          meta: {
            source: weather_data[:source] || 'unknown',
            lastUpdated: weather_data.dig(:cache_info, :cached_at) || Time.current.iso8601,
            ttl: 600, # 10 minutes
            latitude: params[:latitude],
            longitude: params[:longitude],
            timezone: params[:timezone] || data.dig(:metadata, :timezone) || 'America/Los_Angeles'
          }
        }
      end

      def format_forecast(daily_forecast)
        return [] unless daily_forecast.is_a?(Array)

        daily_forecast.first(7).map do |day|
          {
            date: day[:date],
            temperatureMax: day[:temperature_max],
            temperatureMin: day[:temperature_min],
            condition: day[:condition],
            conditionDescription: day[:condition_description],
            precipitationProbability: day[:precipitation_probability],
            humidity: day[:humidity]
          }
        end
      end

      def calculate_dust_level(current_weather)
        # Simple dust level calculation based on wind speed and visibility
        # This is a placeholder - in production you'd want more sophisticated logic
        return 'unknown' unless current_weather

        wind_speed = current_weather[:wind_speed] || 0
        visibility = current_weather[:visibility] || 10

        if wind_speed > 25 && visibility < 2
          'severe'
        elsif wind_speed > 15 && visibility < 5
          'moderate'
        elsif wind_speed > 10
          'light'
        else
          'minimal'
        end
      end

      def calculate_moon_phase
        # Basic moon phase calculation
        # In production, you'd want to use a proper astronomy library
        date = Date.current
        year = date.year
        month = date.month
        day = date.day

        # Simple moon phase algorithm (approximate)
        if month < 3
          year -= 1
          month += 12
        end

        a = year / 100
        b = a / 4
        c = 2 - a + b
        e = (365.25 * (year + 4716)).to_i
        f = (30.6001 * (month + 1)).to_i
        jd = c + day + e + f - 1524.5

        days_since_new_moon = (jd - 2451549.5) % 29.53059
        phase = (days_since_new_moon / 29.53059 * 100).round

        {
          phase: phase_name(phase),
          illumination: phase,
          daysUntilNewMoon: (29.53059 - days_since_new_moon).round
        }
      end

      def phase_name(phase_percentage)
        case phase_percentage
        when 0..6 then 'new'
        when 7..24 then 'waxing crescent'
        when 25..31 then 'first quarter'
        when 32..49 then 'waxing gibbous'
        when 50..56 then 'full'
        when 57..74 then 'waning gibbous'
        when 75..81 then 'last quarter'
        when 82..99 then 'waning crescent'
        else 'new'
        end
      end

      def error_response(message)
        {
          error: {
            message: message,
            timestamp: Time.current.iso8601
          }
        }
      end
    end
  end
end