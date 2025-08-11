# OK-Offline API

Rails 8 API service providing weather data, vector search, and future community features for the OK-Offline ecosystem.

## 🌟 Current Features

### Production Services ✅
- **Weather Service** - Multi-source weather data with fallbacks (OpenWeatherMap + Apple WeatherKit)
- **Vector Search** - AI-powered semantic search using OpenAI embeddings (750+ items indexed)
- **Entity Extraction** - Automatic detection of themes, locations, and activities
- **Search Analytics** - Usage tracking and performance metrics
- **CORS Support** - Configured for frontend integration

### Live in Production
- Three search modes available at https://offline.oknotok.com
- 24-hour result caching implemented
- Graceful offline fallback to keyword search
- URL parameter support for shareable searches

## Requirements

- Ruby 3.3.0
- Rails 8.0.1
- PostgreSQL 14+ with pgvector extension
- Redis (optional, for caching)
- OpenAI API key (for vector search)

## Environment Setup

### 1. Install Dependencies

```bash
bundle install

# Install pgvector extension
# On macOS with Homebrew:
brew install pgvector

# On Ubuntu/Debian:
sudo apt install postgresql-14-pgvector
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

# Vector Search (Optional but recommended)
OPENAI_API_KEY=your_openai_api_key

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

**OpenAI API:**
1. Sign up at https://platform.openai.com
2. Generate an API key from your account
3. Costs ~$0.0004 per 1K tokens for embeddings

### 3. Database Setup

```bash
# Create and setup the database
rails db:create
rails db:migrate
rails db:seed  # Optional: loads sample data

# Enable pgvector extension
rails db -c "CREATE EXTENSION IF NOT EXISTS vector;"
```

### 4. Running the API Server

```bash
# Development server (runs on port 3555 with Tailscale)
rails server -b 0.0.0.0 -p 3555

# Import vector search data (requires OPENAI_API_KEY)
rails search:import[2024]

# Check vector search stats
rails search:stats

# Generate embeddings for existing data
rails search:generate_embeddings
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

### Vector Search API (Live in Production ✅)

#### Semantic Search

```
POST /api/v1/search/vector
```

**Request Body:**
```json
{
  "query": "yoga and meditation camps",
  "year": 2024,
  "types": ["camp", "art", "event"],
  "limit": 20,
  "threshold": 0.7  // Optional: minimum similarity score
}
```

**Response:**
```json
{
  "results": [
    {
      "uid": "abc123",
      "name": "Sunrise Yoga Camp",
      "type": "camp",
      "description": "Daily yoga and meditation...",
      "score": 0.89,
      "location_string": "7:30 & E"
    }
  ],
  "meta": {
    "total": 15,
    "query_time": 0.125
  }
}
```

**Frontend Integration:**
- Available at https://offline.oknotok.com in search view
- Accessible via search mode dropdown
- Results cached for 24 hours in browser

#### Hybrid Search (Vector + Keyword)

```
POST /api/v1/search/hybrid
```

Combines semantic understanding with keyword matching for best results.

#### Entity-Based Search

```
POST /api/v1/search/entities
```

Search by extracted entities like themes, locations, or activities.

#### Search Suggestions

```
POST /api/v1/search/suggest
```

Get autocomplete suggestions based on query prefix.

#### Search Analytics

```
GET /api/v1/search/analytics
```

View search usage statistics and performance metrics (admin only).

### Embedding Management

#### Generate Embeddings

```
POST /api/v1/embeddings/generate
```

Generate embeddings for new content.

#### Batch Import

```
POST /api/v1/embeddings/batch_import
```

Import and embed data from JSON files.

#### Import Status

```
GET /api/v1/embeddings/status
```

Check the status of ongoing import operations.

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

# Run vector search tests
rails test test/services/search/
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
- `http://dev.offline.oknotok.com:8005`
- `https://offline.oknotok.com`
- Any localhost port in 8000-8999 range

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

The system uses a service-oriented architecture:

1. **WeatherAggregatorService** - Coordinates multiple weather sources
2. **OpenWeatherService** - Fetches data from OpenWeatherMap
3. **AppleWeather** - Fetches data from Apple WeatherKit
4. **WeatherCacheService** - Handles caching logic
5. **Search::EmbeddingService** - OpenAI embedding generation
6. **Search::EntityExtractionService** - Extract entities from text
7. **Search::VectorSearchService** - Similarity search logic
8. **Search::DataImportService** - Import data from JSON files

Services failover gracefully: if Apple Weather fails, it falls back to OpenWeather.

## Vector Search Details

### Database Schema

The vector search uses pgvector for efficient similarity search:

```ruby
# SearchableItem model
- uid: string
- item_type: string (camp/art/event)
- year: integer
- name: string
- description: text
- searchable_text: text
- embedding: vector(1536)
- metadata: json

# SearchEntity model
- entity_type: string
- entity_value: string
- confidence: float
```

### Search Performance

- Vector similarity search: < 100ms (HNSW index)
- Hybrid search: < 200ms
- Batch embedding: 50 items per API call
- Current dataset: 750+ items indexed

### Cost Management

- OpenAI embeddings: ~$0.0004 per 1K tokens
- Average item: ~500 tokens
- Full dataset embedding: < $1
- Monitor usage with `rails search:stats`

## Deployment

### Production Configuration

Ensure these environment variables are set in production:
- All weather API keys
- OpenAI API key for vector search
- `RAILS_MASTER_KEY` for credentials decryption
- Database connection settings
- Redis URL for caching (optional)

### Docker Support

```bash
# Build the Docker image
docker build -t ok-offline-api .

# Run the container
docker run -p 3555:3555 --env-file .env ok-offline-api
```

## Troubleshooting

### Weather API Returns 503

1. Check API keys are correctly set in environment
2. Verify external weather services are accessible
3. Check logs: `tail -f log/development.log`
4. Run test script: `ruby test_weather.rb`

### Vector Search Not Working

1. Ensure OPENAI_API_KEY is set
2. Check pgvector extension: `rails db -c "SELECT * FROM pg_extension WHERE extname = 'vector';"`
3. Run data import: `rails search:import[2024]`
4. Check embeddings: `rails console` then `SearchableItem.count`

### CORS Issues

1. Verify allowed origins in `config/initializers/cors.rb`
2. Check browser console for specific CORS errors
3. Ensure frontend is making requests to correct API URL

### Database Connection Issues

1. Verify PostgreSQL is running: `pg_ctl status`
2. Check database.yml configuration
3. Ensure database exists: `rails db:create`
4. Verify pgvector installed: `CREATE EXTENSION vector;`

## API Documentation

For detailed API documentation including all endpoints, see:
- [API_DOCUMENTATION.md](API_DOCUMENTATION.md) - Complete endpoint reference
- [VECTOR_SEARCH_API.md](VECTOR_SEARCH_API.md) - Vector search specifics

## Contributing

This is part of the OK-Offline ecosystem for Burning Man participants. When contributing:
1. Ensure all features work offline-first
2. Test in harsh conditions (limited connectivity)
3. Prioritize reliability over real-time features
4. Follow Rails best practices
5. Add tests for new features

## License

Created by Jeremy Roush and brought to you by Mr. OK of OKNOTOK.