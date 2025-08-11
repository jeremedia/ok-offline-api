# OK-Offline API Documentation

## Overview

The OK-Offline API provides backend services for the Burning Man offline ecosystem, including weather data, vector search, and social sharing features.

## Base URLs

- Development: `http://dev.offline.oknotok.com`
- Production: `https://offline.oknotok.com/api/v1` 

## API Version

Current version: `v1`

All endpoints are prefixed with `/api/v1/`

## Available Services

### Core Services

1. **[Weather API](./weather_api.md)** - Current conditions and forecasts
   - `POST /api/v1/weather/current` - Get weather data for coordinates

2. **[OpenGraph API](./opengraph_api.md)** - Social media image generation
   - `POST /api/v1/opengraph/generate` - Generate OpenGraph images
   - `GET /api/v1/opengraph/test` - Test template in browser

3. **[Vector Search API](./search_api.md)** - AI-powered semantic search
   - `POST /api/v1/search/vector` - Semantic search
   - `POST /api/v1/search/hybrid` - Combined keyword + semantic search
   - `POST /api/v1/search/suggest` - Autocomplete suggestions

### System Endpoints

- `GET /up` - Health check endpoint

## Authentication

Currently, the API is open access. Future versions will implement:
- API key authentication for rate limiting
- JWT tokens for user-specific features

## Common Response Formats

### Success Response
```json
{
  "data": { ... },
  "meta": {
    "timestamp": "2024-08-26T15:30:00Z",
    ...
  }
}
```

### Error Response
```json
{
  "error": {
    "message": "Error description",
    "timestamp": "2024-08-26T15:30:00Z"
  }
}
```

## CORS Policy

The API allows cross-origin requests from:
- `https://dev.offline.oknotok.com` (development)
- `https://offline.oknotok.com` (production)

## Rate Limiting

Currently no rate limiting is implemented. Future versions will enforce:
- 1000 requests per hour per IP
- 10,000 requests per day per API key

## Environment Setup

See individual API documentation for specific environment requirements:
- [Weather API Environment](./weather_api.md#environment-setup)
- [Vector Search Environment](./search_api.md#environment-setup)

## Support

For issues or questions:
- GitHub: https://github.com/jeremywrush/ok-offline-ecosystem
- Created by Jeremy Roush and Mr. OK of OKNOTOK