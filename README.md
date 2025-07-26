# OK-Offline API

Rails 8 API service providing weather data and future community features for the OK-Offline ecosystem.

## Requirements

- Ruby 3.3.0
- Rails 8.0.1
- PostgreSQL 14+
- Redis (optional, for caching)

## Environment Setup

### 1. Install Dependencies

```bash
bundle install
```

### 2. Environment Variables

Create a `.env` file in the root directory (or set these in your environment):

```bash
# Weather Service API Keys
OPENWEATHER_API_KEY=your_openweather_api_key

# Apple WeatherKit Configuration
APPLE_WEATHER_KEY_ID=your_apple_weather_key_id
APPLE_WEATHER_TEAM_ID=your_apple_team_id
APPLE_WEATHER_SERVICE_ID=your_apple_service_id
APPLE_WEATHER_PRIVATE_KEY_PATH=path/to/your/apple_key.p8

# Rails Configuration
RAILS_ENV=development
```

#### Getting API Keys

**OpenWeather API:**
1. Sign up at https://openweathermap.org/api
2. Generate an API key from your account dashboard
3. Free tier includes 1,000 calls/day

**Apple WeatherKit:**
1. Requires Apple Developer account
2. Create a WeatherKit key in Apple Developer portal
3. Download the .p8 private key file
4. Note your Team ID, Service ID, and Key ID

### 3. Database Setup

```bash
# Create and setup the database
rails db:create
rails db:migrate
rails db:seed  # Optional: loads sample data
```

### 4. Running the API Server

```bash
# Development server (runs on port 3000)
rails server

# Or specify a different port
rails server -p 3001
```

## API Endpoints

### Health Check

```
GET /up
```

Returns 200 if the app is running properly.

### Weather API

#### Get Current Weather

```
POST /api/v1/weather/current
```

**Request Body:**
```json
{
  "latitude": 40.7874,
  "longitude": -119.2065,
  "timezone": "America/Los_Angeles"  // Optional
}
```

**Success Response (200):**
```json
{
  "data": {
    "temperature": 85.5,
    "windSpeed": 12.3,
    "windDirection": 245,
    "humidity": 15,
    "pressure": 1013.25,
    "visibility": 10,
    "condition": "clear",
    "conditionDescription": "Clear sky",
    "feelsLike": 82.1,
    "dustLevel": "moderate",
    "moonPhase": {
      "phase": "waxing gibbous",
      "illumination": 67,
      "daysUntilNewMoon": 10
    },
    "forecast": [
      {
        "date": "2024-08-26",
        "temperatureMax": 95,
        "temperatureMin": 65,
        "condition": "clear",
        "conditionDescription": "Clear sky",
        "precipitationProbability": 0,
        "humidity": 20
      }
    ]
  },
  "meta": {
    "source": "openweather",
    "lastUpdated": "2024-08-26T15:30:00Z",
    "ttl": 600,
    "latitude": "40.7874",
    "longitude": "-119.2065",
    "timezone": "America/Los_Angeles"
  }
}
```

**Error Response (400 - Bad Request):**
```json
{
  "error": {
    "message": "Missing required parameters: latitude and longitude",
    "timestamp": "2024-08-26T15:30:00Z"
  }
}
```

**Error Response (503 - Service Unavailable):**
```json
{
  "error": {
    "message": "Weather service temporarily unavailable",
    "timestamp": "2024-08-26T15:30:00Z"
  }
}
```

### Legacy Endpoints (Deprecated)

These endpoints are maintained for backward compatibility but should not be used for new integrations:

```
GET /weather              # Returns weather for default location
DELETE /weather/cache     # Clears weather cache
```

## Error Handling

The API uses standard HTTP status codes:

- `200 OK` - Request succeeded
- `400 Bad Request` - Invalid parameters
- `401 Unauthorized` - Missing or invalid API key (future)
- `503 Service Unavailable` - Weather service temporarily down
- `500 Internal Server Error` - Unexpected server error

All error responses include:
- Error message describing the issue
- Timestamp of when the error occurred

## Testing

### Run the Test Suite

```bash
# Run all tests
rails test

# Run specific test file
rails test test/controllers/api/v1/weather_controller_test.rb
```

### Test Weather Integration

A test script is included to verify weather service configuration:

```bash
ruby test_weather.rb
```

This will:
- Check all environment variables are set
- Test connections to weather services
- Display sample weather data

## Development Tips

### CORS Configuration

CORS is configured in `config/initializers/cors.rb` to allow requests from:
- `http://localhost:8000` (frontend development)
- `https://offline.oknotok.com` (production frontend)

### Caching

Weather data is cached for 10 minutes to:
- Reduce API calls to external services
- Improve response times
- Provide fallback data if services are down

Clear cache manually:
```bash
rails console
Rails.cache.clear
```

### Service Architecture

The weather system uses a service-oriented architecture:

1. **WeatherAggregatorService** - Coordinates multiple weather sources
2. **OpenWeatherService** - Fetches data from OpenWeatherMap
3. **AppleWeather** - Fetches data from Apple WeatherKit
4. **WeatherCacheService** - Handles caching logic

Services failover gracefully: if Apple Weather fails, it falls back to OpenWeather.

## Deployment

### Production Configuration

Ensure these environment variables are set in production:
- All weather API keys
- `RAILS_MASTER_KEY` for credentials decryption
- Database connection settings
- Redis URL for caching (optional)

### Docker Support

```bash
# Build the Docker image
docker build -t ok-offline-api .

# Run the container
docker run -p 3000:3000 --env-file .env ok-offline-api
```

## Troubleshooting

### Weather API Returns 503

1. Check API keys are correctly set in environment
2. Verify external weather services are accessible
3. Check logs: `tail -f log/development.log`
4. Run test script: `ruby test_weather.rb`

### CORS Issues

1. Verify allowed origins in `config/initializers/cors.rb`
2. Check browser console for specific CORS errors
3. Ensure frontend is making requests to correct API URL

### Database Connection Issues

1. Verify PostgreSQL is running: `pg_ctl status`
2. Check database.yml configuration
3. Ensure database exists: `rails db:create`

## Contributing

This is part of the OK-Offline ecosystem for Burning Man participants. When contributing:
1. Ensure all features work offline-first
2. Test in harsh conditions (limited connectivity)
3. Prioritize reliability over real-time features

## License

Created by Jeremy Roush and brought to you by Mr. OK of OKNOTOK.
