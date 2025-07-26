# frozen_string_literal: true

class WeatherCacheService
  CACHE_DURATION = 10.minutes # Cache weather data for 10 minutes
  CACHE_KEY_PREFIX = 'weather_data'

  def initialize(latitude, longitude)
    @latitude = latitude.to_f.round(4) # Round to 4 decimal places for reasonable precision
    @longitude = longitude.to_f.round(4)
    @cache_key = "#{CACHE_KEY_PREFIX}:#{@latitude}:#{@longitude}"
  end

  def fetch
    cached_data = Rails.cache.read(@cache_key)
    
    if cached_data
      Rails.logger.info "Weather cache hit for coordinates: #{@latitude}, #{@longitude}"
      add_cache_metadata(cached_data, true)
    else
      Rails.logger.info "Weather cache miss for coordinates: #{@latitude}, #{@longitude}"
      nil
    end
  end

  def store(weather_data)
    return unless weather_data && weather_data[:success]

    Rails.logger.info "Storing weather data in cache for coordinates: #{@latitude}, #{@longitude}"
    
    # Add timestamp to the cached data
    data_with_timestamp = weather_data.merge(
      cached_at: Time.current.iso8601
    )
    
    Rails.cache.write(@cache_key, data_with_timestamp, expires_in: CACHE_DURATION)
    
    add_cache_metadata(data_with_timestamp, false)
  end

  def clear
    Rails.cache.delete(@cache_key)
    Rails.logger.info "Cleared weather cache for coordinates: #{@latitude}, #{@longitude}"
  end

  def clear_all
    # Clear all weather cache entries
    # Note: This is a nuclear option and should be used sparingly
    if Rails.cache.respond_to?(:delete_matched)
      Rails.cache.delete_matched("#{CACHE_KEY_PREFIX}:*")
      Rails.logger.info "Cleared all weather cache entries"
    else
      Rails.logger.warn "Cache store does not support delete_matched. Unable to clear all weather caches."
    end
  end

  private

  def add_cache_metadata(data, from_cache)
    return data unless data.is_a?(Hash)
    
    cached_at = data[:cached_at] || Time.current.iso8601
    expires_at = begin
      (Time.parse(cached_at) + CACHE_DURATION).iso8601
    rescue ArgumentError
      (Time.current + CACHE_DURATION).iso8601
    end
    
    data.merge(
      cache_info: {
        from_cache: from_cache,
        cached_at: cached_at,
        expires_at: expires_at,
        cache_key: @cache_key
      }
    )
  end
end