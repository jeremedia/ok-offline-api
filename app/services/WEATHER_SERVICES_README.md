# Weather Aggregation Services

This directory contains the weather aggregation services for the OK-OFFLINE API. The system is designed to provide reliable weather data through multiple sources with automatic failover and caching.

## Services Overview

### 1. WeatherAggregatorService
The main orchestration service that manages weather data fetching with the following priority:
1. Check cache first
2. Try OpenWeatherMap (primary source)
3. Fall back to Apple Weather if OpenWeather fails
4. Return stale cache data if all APIs fail

### 2. OpenWeatherService
Integrates with OpenWeatherMap API for current weather and 5-day forecast data.

### 3. AppleWeather
Integrates with Apple WeatherKit API using JWT authentication.

### 4. WeatherCacheService
Handles caching of weather responses with a 10-minute TTL to reduce API calls and improve performance.

## API Endpoints

### Get Weather Data
```
GET /weather?lat=36.598&lon=-121.874
```

Response format:
```json
{
  "success": true,
  "source": "openweather",
  "data": {
    "current_weather": {
      "temperature": 72.5,
      "feels_like": 70.1,
      "humidity": 65,
      "pressure": 1013,
      "visibility": 10.0,
      "wind_speed": 5.2,
      "wind_direction": 180,
      "condition": "Clear",
      "condition_description": "clear sky",
      "icon": "01d",
      "timestamp": "2024-01-26T10:30:00Z"
    },
    "forecast_daily": [
      {
        "date": "2024-01-26",
        "temperature_max": 75.0,
        "temperature_min": 55.0,
        "condition": "Clear",
        "condition_description": "clear sky",
        "precipitation_probability": 0,
        "humidity": 60
      }
    ],
    "metadata": {
      "latitude": "36.598",
      "longitude": "-121.874",
      "timezone": "America/Los_Angeles",
      "units": "imperial"
    }
  },
  "cache_info": {
    "from_cache": false,
    "cached_at": "2024-01-26T10:30:00Z",
    "expires_at": "2024-01-26T10:40:00Z",
    "cache_key": "weather_data:36.598:-121.8744"
  }
}
```

### Clear Weather Cache
```
DELETE /weather/cache?lat=36.598&lon=-121.874
```
Or clear all caches:
```
DELETE /weather/cache
```

## Configuration

### Environment Variables

```bash
# OpenWeather API
OPENWEATHER_API_KEY=your_openweather_api_key_here

# Apple Weather API
APPLE_WEATHER_KEY_ID=YOUR_APPLE_KEY_ID
APPLE_WEATHER_SERVICE_ID=YOUR_APPLE_SERVICE_ID
APPLE_WEATHER_TEAM_ID=YOUR_APPLE_TEAM_ID
APPLE_WEATHER_PRIVATE_KEY_PATH=app/services/apple_key
```

### Apple Weather Private Key
Place your Apple Weather private key (p8 file) at:
```
app/services/apple_key
```

## Testing

Run the test script to verify the services are working:
```bash
rails runner test_weather.rb
```

## Error Handling

The services implement comprehensive error handling:
- API connection failures
- Invalid responses
- Missing API keys
- Rate limiting
- Invalid coordinates

All errors are logged with appropriate context for debugging.

## Cache Strategy

- Cache duration: 10 minutes
- Cache key format: `weather_data:{rounded_lat}:{rounded_lon}`
- Coordinates are rounded to 4 decimal places for reasonable precision
- Cache is checked before making any API calls
- Successful responses are automatically cached

## Units

All weather data is returned in Imperial units:
- Temperature: Fahrenheit
- Wind speed: mph
- Visibility: miles
- Pressure: hPa (hectopascals)

## Logging

All services include detailed logging:
- Info level: Successful operations, cache hits/misses
- Warn level: API failures, fallback operations
- Error level: Exceptions, critical failures

Check Rails logs for debugging:
```bash
tail -f log/development.log | grep -E "(Weather|OpenWeather|Apple)"
```