# OK-Offline API Documentation

## Overview

The OK-Offline API provides weather data and future community features for the Burning Man offline ecosystem. This document details all available endpoints, request/response formats, and integration guidelines.

## Base URL

- Development: `http://localhost:3000`
- Production: `https://api.offline.oknotok.com` (TBD)

## Authentication

Currently, the API is open access. Future versions will implement API key authentication for rate limiting and access control.

## API Versioning

The API uses URL path versioning. Current version: `v1`

All v1 endpoints are prefixed with `/api/v1/`

## Available Endpoints

### 1. Health Check

Verify the API service is running and healthy.

#### Request
```http
GET /up
```

#### Response
```http
HTTP/1.1 200 OK
Content-Type: text/html

<!DOCTYPE html><html><body style="background-color: green"></body></html>
```

### 2. Current Weather

Get current weather conditions and forecast for specified coordinates.

#### Request
```http
POST /api/v1/weather/current
Content-Type: application/json

{
  "latitude": 40.7874,
  "longitude": -119.2065,
  "timezone": "America/Los_Angeles"  // Optional, defaults to America/Los_Angeles
}
```

#### Parameters

| Parameter | Type   | Required | Description | Constraints |
|-----------|--------|----------|-------------|-------------|
| latitude  | float  | Yes      | Location latitude | -90 to 90 |
| longitude | float  | Yes      | Location longitude | -180 to 180 |
| timezone  | string | No       | IANA timezone identifier | Valid timezone |

#### Success Response (200 OK)
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
      },
      {
        "date": "2024-08-27",
        "temperatureMax": 93,
        "temperatureMin": 64,
        "condition": "partly_cloudy",
        "conditionDescription": "Partly cloudy",
        "precipitationProbability": 5,
        "humidity": 22
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

#### Response Fields

**data Object:**

| Field | Type | Description | Units |
|-------|------|-------------|-------|
| temperature | float | Current temperature | Fahrenheit |
| windSpeed | float | Current wind speed | mph |
| windDirection | integer | Wind direction | degrees (0-360) |
| humidity | integer | Relative humidity | percentage |
| pressure | float | Atmospheric pressure | hPa |
| visibility | float | Visibility distance | miles |
| condition | string | Weather condition code | see conditions below |
| conditionDescription | string | Human-readable condition | English text |
| feelsLike | float | Apparent temperature | Fahrenheit |
| dustLevel | string | Dust storm level | minimal/light/moderate/severe |
| moonPhase | object | Moon phase information | see below |
| forecast | array | 7-day forecast | see below |

**moonPhase Object:**

| Field | Type | Description |
|-------|------|-------------|
| phase | string | Current moon phase name |
| illumination | integer | Moon illumination percentage (0-100) |
| daysUntilNewMoon | integer | Days until next new moon |

**forecast Array Items:**

| Field | Type | Description | Units |
|-------|------|-------------|-------|
| date | string | Forecast date | ISO 8601 date |
| temperatureMax | float | Maximum temperature | Fahrenheit |
| temperatureMin | float | Minimum temperature | Fahrenheit |
| condition | string | Weather condition code | see conditions below |
| conditionDescription | string | Human-readable condition | English text |
| precipitationProbability | integer | Chance of precipitation | percentage |
| humidity | integer | Average humidity | percentage |

**meta Object:**

| Field | Type | Description |
|-------|------|-------------|
| source | string | Data source (openweather/apple) |
| lastUpdated | string | ISO 8601 timestamp of data |
| ttl | integer | Time to live in seconds |
| latitude | string | Requested latitude |
| longitude | string | Requested longitude |
| timezone | string | Timezone for forecast dates |

#### Weather Conditions

Common condition codes returned by the API:

- `clear` - Clear sky
- `partly_cloudy` - Few clouds
- `cloudy` - Scattered or broken clouds
- `overcast` - Overcast clouds
- `rain` - Rain
- `thunderstorm` - Thunderstorm
- `snow` - Snow
- `mist` - Mist/fog
- `dust` - Dust storm

#### Dust Levels

The API calculates dust levels based on wind speed and visibility:

- `minimal` - Calm conditions, good visibility
- `light` - Light winds (10+ mph)
- `moderate` - Moderate winds (15+ mph) with reduced visibility
- `severe` - Strong winds (25+ mph) with poor visibility

#### Error Responses

**400 Bad Request - Missing Parameters**
```json
{
  "error": {
    "message": "Missing required parameters: latitude and longitude",
    "timestamp": "2024-08-26T15:30:00Z"
  }
}
```

**400 Bad Request - Invalid Coordinates**
```json
{
  "error": {
    "message": "Invalid latitude. Must be between -90 and 90",
    "timestamp": "2024-08-26T15:30:00Z"
  }
}
```

**503 Service Unavailable**
```json
{
  "error": {
    "message": "Weather service temporarily unavailable",
    "timestamp": "2024-08-26T15:30:00Z"
  }
}
```

**500 Internal Server Error**
```json
{
  "error": {
    "message": "Internal server error",
    "timestamp": "2024-08-26T15:30:00Z"
  }
}
```

## Rate Limiting

Currently no rate limiting is implemented. Future versions will enforce:
- 1000 requests per hour per IP
- 10,000 requests per day per API key

## Caching

Weather data is cached for 10 minutes (600 seconds) to:
- Reduce load on external weather services
- Improve response times
- Provide resilience during service outages

The cache TTL is included in the response metadata.

## CORS Policy

The API allows cross-origin requests from:
- `http://localhost:8000` (development)
- `https://offline.oknotok.com` (production)

Other origins will receive CORS errors.

## Environment Setup

### Required Environment Variables

```bash
# Weather Service Configuration
OPENWEATHER_API_KEY=your_openweather_api_key

# Apple WeatherKit Configuration
APPLE_WEATHER_KEY_ID=your_key_id
APPLE_WEATHER_TEAM_ID=your_team_id
APPLE_WEATHER_SERVICE_ID=your_service_id
APPLE_WEATHER_PRIVATE_KEY_PATH=path/to/private_key.p8
```

### Obtaining API Keys

#### OpenWeatherMap
1. Create account at https://openweathermap.org/
2. Generate API key in account settings
3. Free tier: 1,000 calls/day

#### Apple WeatherKit
1. Requires Apple Developer account ($99/year)
2. Create WeatherKit key in Certificates, Identifiers & Profiles
3. Download .p8 private key file
4. Note Team ID, Service ID, and Key ID

## Integration Examples

### JavaScript/Fetch
```javascript
const response = await fetch('http://localhost:3000/api/v1/weather/current', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    latitude: 40.7874,
    longitude: -119.2065
  })
});

const weather = await response.json();
console.log(`Current temperature: ${weather.data.temperature}°F`);
```

### cURL
```bash
curl -X POST http://localhost:3000/api/v1/weather/current \
  -H "Content-Type: application/json" \
  -d '{
    "latitude": 40.7874,
    "longitude": -119.2065
  }'
```

### Python
```python
import requests

response = requests.post(
    'http://localhost:3000/api/v1/weather/current',
    json={
        'latitude': 40.7874,
        'longitude': -119.2065
    }
)

weather = response.json()
print(f"Current temperature: {weather['data']['temperature']}°F")
```

## Error Handling Best Practices

1. **Always check HTTP status codes** before parsing response body
2. **Handle 503 errors gracefully** - the service may be temporarily down
3. **Implement exponential backoff** for retries
4. **Cache successful responses** locally for offline functionality
5. **Validate coordinates** before sending requests

## Future Endpoints (Planned)

### User Authentication
- `POST /api/v1/auth/signup` - Create account
- `POST /api/v1/auth/login` - Authenticate
- `POST /api/v1/auth/logout` - End session

### Playa Wisdom (Community Content)
- `GET /api/v1/wisdom` - List wisdom posts
- `POST /api/v1/wisdom` - Create wisdom post
- `GET /api/v1/wisdom/:id` - Get specific post
- `PUT /api/v1/wisdom/:id` - Update post
- `DELETE /api/v1/wisdom/:id` - Delete post

### User Favorites
- `GET /api/v1/favorites` - List user favorites
- `POST /api/v1/favorites` - Add favorite
- `DELETE /api/v1/favorites/:id` - Remove favorite

## Support

For issues or questions:
- GitHub: https://github.com/jeremywrush/ok-offline-api
- Created by Jeremy Roush and Mr. OK of OKNOTOK

## Changelog

### v1.0.0 (2024-01-26)
- Initial release
- Weather endpoint with OpenWeatherMap and Apple WeatherKit support
- Basic caching and error handling
- CORS support for frontend integration