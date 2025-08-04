# Weather API Documentation

## Overview

Get current weather conditions and forecast for specified coordinates, optimized for Black Rock City conditions with dust level calculations.

## Endpoint

### Current Weather

**POST** `/api/v1/weather/current`

Get current weather conditions and 7-day forecast.

#### Request

**Headers:**
```
Content-Type: application/json
```

**Body Parameters:**
```json
{
  "latitude": 40.7874,
  "longitude": -119.2065,
  "timezone": "America/Los_Angeles"
}
```

| Parameter | Type   | Required | Description | Constraints |
|-----------|--------|----------|-------------|-------------|
| latitude  | float  | Yes      | Location latitude | -90 to 90 |
| longitude | float  | Yes      | Location longitude | -180 to 180 |
| timezone  | string | No       | IANA timezone identifier | Valid timezone |

#### Response

**Success (200 OK):**
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

## Response Fields

### data Object

| Field | Type | Description | Units |
|-------|------|-------------|-------|
| temperature | float | Current temperature | Fahrenheit |
| windSpeed | float | Current wind speed | mph |
| windDirection | integer | Wind direction | degrees (0-360) |
| humidity | integer | Relative humidity | percentage |
| pressure | float | Atmospheric pressure | hPa |
| visibility | float | Visibility distance | miles |
| condition | string | Weather condition code | see below |
| conditionDescription | string | Human-readable condition | English text |
| feelsLike | float | Apparent temperature | Fahrenheit |
| dustLevel | string | Dust storm level | see below |
| moonPhase | object | Moon phase information | see below |
| forecast | array | 7-day forecast | see below |

### moonPhase Object

| Field | Type | Description |
|-------|------|-------------|
| phase | string | Current moon phase name |
| illumination | integer | Moon illumination percentage (0-100) |
| daysUntilNewMoon | integer | Days until next new moon |

### forecast Array Items

| Field | Type | Description | Units |
|-------|------|-------------|-------|
| date | string | Forecast date | ISO 8601 date |
| temperatureMax | float | Maximum temperature | Fahrenheit |
| temperatureMin | float | Minimum temperature | Fahrenheit |
| condition | string | Weather condition code | see below |
| conditionDescription | string | Human-readable condition | English text |
| precipitationProbability | integer | Chance of precipitation | percentage |
| humidity | integer | Average humidity | percentage |

## Weather Conditions

Common condition codes:
- `clear` - Clear sky
- `partly_cloudy` - Few clouds
- `cloudy` - Scattered or broken clouds
- `overcast` - Overcast clouds
- `rain` - Rain
- `thunderstorm` - Thunderstorm
- `dust` - Dust storm

## Dust Levels

Calculated based on wind speed and visibility:
- `minimal` - Calm conditions, good visibility
- `light` - Light winds (10+ mph)
- `moderate` - Moderate winds (15+ mph) with reduced visibility
- `severe` - Strong winds (25+ mph) with poor visibility

## Error Responses

**400 Bad Request - Missing Parameters**
```json
{
  "error": {
    "message": "Missing required parameters: latitude and longitude",
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

## Example Usage

### JavaScript
```javascript
const response = await fetch('http://100.104.170.10:3555/api/v1/weather/current', {
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
console.log(`Dust level: ${weather.data.dustLevel}`);
```

### cURL
```bash
curl -X POST http://100.104.170.10:3555/api/v1/weather/current \
  -H "Content-Type: application/json" \
  -d '{
    "latitude": 40.7874,
    "longitude": -119.2065
  }'
```

## Environment Setup

### Required Environment Variables

```bash
# OpenWeatherMap Configuration
OPENWEATHER_API_KEY=your_openweather_api_key

# Apple WeatherKit Configuration (Fallback)
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

## Caching

Weather data is cached for 10 minutes (600 seconds) to:
- Reduce load on external weather services
- Improve response times
- Provide resilience during service outages

The cache TTL is included in the response metadata.