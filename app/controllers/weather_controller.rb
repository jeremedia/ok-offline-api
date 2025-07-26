# frozen_string_literal: true

class WeatherController < ApplicationController
  before_action :validate_coordinates, only: [:show]

def test
    render json: { message: 'Weather API is working' }
    end

  # GET /weather?lat=36.598&lon=-121.874
  def show
    weather_aggregator = WeatherAggregatorService.new(params[:lat], params[:lon])
    weather_data = weather_aggregator.fetch_weather

    if weather_data[:success]
      render json: weather_data
    else
      render json: { 
        success: false, 
        error: weather_data[:error] || 'Unable to fetch weather data from any source' 
      }, status: :service_unavailable
    end
  end

  # DELETE /weather/cache?lat=36.598&lon=-121.874
  def clear_cache
    if params[:lat].present? && params[:lon].present?
      weather_aggregator = WeatherAggregatorService.new(params[:lat], params[:lon])
      weather_aggregator.clear_cache
      render json: { success: true, message: 'Cache cleared for specified coordinates' }
    else
      # Clear all weather caches if no coordinates provided
      WeatherCacheService.new(0, 0).clear_all
      render json: { success: true, message: 'All weather caches cleared' }
    end
  end

  private

  def validate_coordinates
    unless params[:lat].present? && params[:lon].present?
      render json: { 
        success: false, 
        error: 'Missing required parameters: lat and lon' 
      }, status: :bad_request
      return
    end

    begin
      latitude = Float(params[:lat])
      longitude = Float(params[:lon])

      # Basic coordinate validation
      unless latitude.between?(-90, 90) && longitude.between?(-180, 180)
        render json: { 
          success: false, 
          error: 'Invalid coordinates. Latitude must be between -90 and 90, longitude between -180 and 180' 
        }, status: :bad_request
      end
    rescue ArgumentError
      render json: { 
        success: false, 
        error: 'Invalid coordinate format. Please provide numeric values' 
      }, status: :bad_request
    end
  end
end