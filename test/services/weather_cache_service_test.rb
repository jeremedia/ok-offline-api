require_relative "../test_helper"

class WeatherCacheServiceTest < ActiveSupport::TestCase
  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end
  teardown { Rails.cache = @original_cache }

  test "preserves and labels the last successful response beyond the normal ttl" do
    service = WeatherCacheService.new(40.7832, -119.2079)
    service.store(success: true, source: "openweather", data: { current_weather: { temperature: 82 } })
    Rails.cache.delete("weather_data:40.7832:-119.2079")

    stale = service.fetch_stale
    assert_equal true, stale.dig(:cache_info, :stale)
    assert_equal 82, stale.dig(:data, :current_weather, :temperature)
    assert_operator stale.dig(:cache_info, :age_seconds), :>=, 0
  end
end
