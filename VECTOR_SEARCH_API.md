# Vector Search API Documentation

## Overview

The OK-OFFLINE Vector Search API provides intelligent, semantic search capabilities for Burning Man camps, art installations, and events. Using OpenAI embeddings and PostgreSQL's pgvector extension, the API enables users to find content based on meaning rather than just keyword matching.

## Prerequisites

### Environment Variables
```bash
OPENAI_API_KEY=your_openai_api_key_here
```

### Database Setup
```bash
# Install pgvector extension (PostgreSQL must be installed)
brew install pgvector

# Run migrations
rails db:migrate

# Import data (replace 2025 with desired year)
rails search:import[2025]
```

## API Endpoints

### 1. Vector Search
Performs semantic similarity search using OpenAI embeddings.

**Endpoint:** `POST /api/v1/search/vector`

**Request Body:**
```json
{
  "query": "sustainable art installations with fire",
  "year": 2025,
  "types": ["art", "camp"],
  "limit": 20,
  "threshold": 0.7
}
```

**Parameters:**
- `query` (required): Search query text
- `year` (optional): Year to search (default: 2025)
- `types` (optional): Array of item types: `["camp", "art", "event"]`
- `limit` (optional): Maximum results to return (default: 20)
- `threshold` (optional): Similarity threshold 0-1 (default: 0.7)

**Response:**
```json
{
  "results": [
    {
      "uid": "a1XVI000008yf262AA",
      "name": "Solar Fire Garden",
      "type": "art",
      "description": "Interactive installation combining solar power and flame effects...",
      "similarity_score": 0.8523,
      "metadata": { /* original item data */ },
      "entities": [
        ["theme", "sustainability"],
        ["activity", "fire art"]
      ]
    }
  ],
  "meta": {
    "total_count": 15,
    "execution_time": 245.5,
    "search_type": "vector"
  }
}
```

### 2. Hybrid Search
Combines vector similarity with keyword matching for best results.

**Endpoint:** `POST /api/v1/search/hybrid`

**Request Body:**
```json
{
  "query": "yoga at sunrise",
  "year": 2025,
  "types": ["camp", "event"],
  "limit": 30
}
```

**Response:** Same format as vector search

### 3. Entity Search
Search by extracted entities (locations, activities, themes).

**Endpoint:** `POST /api/v1/search/entities`

**Request Body:**
```json
{
  "entities": ["7:30 Plaza", "workshops", "sustainability"],
  "year": 2025,
  "types": ["camp"],
  "limit": 20
}
```

**Parameters:**
- `entities` (required): Array of entity values to search for
- Other parameters same as vector search

### 4. Search Suggestions
Get autocomplete suggestions based on extracted entities.

**Endpoint:** `POST /api/v1/search/suggest`

**Request Body:**
```json
{
  "query": "work"
}
```

**Response:**
```json
{
  "query": "work",
  "suggestions": [
    "workshops",
    "workshop",
    "working",
    "artwork"
  ]
}
```

### 5. Search Analytics
Get search usage statistics (useful for optimization).

**Endpoint:** `GET /api/v1/search/analytics`

**Response:**
```json
{
  "popular_queries": {
    "music": 45,
    "workshops": 38,
    "coffee": 32
  },
  "average_execution_time": {
    "vector": 0.245,
    "hybrid": 0.189,
    "entity": 0.067
  },
  "success_rate": 87.5,
  "total_searches": 1234
}
```

## Embedding Management

### Generate Embedding
Generate an embedding for arbitrary text.

**Endpoint:** `POST /api/v1/embeddings/generate`

**Request Body:**
```json
{
  "text": "Interactive fire sculpture with renewable energy"
}
```

**Response:**
```json
{
  "text": "Interactive fire sculpture...",
  "embedding": [0.0123, -0.0456, ...],
  "model": "text-embedding-ada-002",
  "dimensions": 1536
}
```

### Batch Import Data
Import and generate embeddings for Burning Man data.

**Endpoint:** `POST /api/v1/embeddings/batch_import`

**Request Body:**
```json
{
  "year": 2025,
  "types": ["camp", "art", "event"]
}
```

**Response:**
```json
{
  "message": "Import job queued",
  "year": 2025,
  "types": ["camp", "art", "event"],
  "job_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

### Import Status
Check the status of embedding generation.

**Endpoint:** `GET /api/v1/embeddings/status`

**Response:**
```json
{
  "total_items": 1500,
  "items_with_embeddings": 1200,
  "percentage_complete": 80.0,
  "by_type": [
    {
      "type": "camp",
      "total": 800,
      "with_embeddings": 750,
      "percentage": 93.75
    },
    {
      "type": "art",
      "total": 400,
      "with_embeddings": 300,
      "percentage": 75.0
    }
  ]
}
```

## Error Responses

### 400 Bad Request
```json
{
  "error": "Text is required"
}
```

### 422 Unprocessable Entity
```json
{
  "error": "Failed to generate query embedding",
  "results": [],
  "meta": {
    "execution_time": 0,
    "search_type": "vector"
  }
}
```

### 500 Internal Server Error
```json
{
  "error": "Internal server error"
}
```

## Rate Limiting

The API implements rate limiting to prevent abuse:
- OpenAI API calls are batched and rate-limited
- Search queries are limited to 100 requests per minute per IP
- Embedding generation is queued to respect OpenAI limits

## Best Practices

### Query Optimization
1. Use descriptive queries for better semantic matching
2. Combine multiple concepts in one query
3. Use entity search for location-based queries

### Performance Tips
1. Set appropriate similarity thresholds (0.7-0.8 recommended)
2. Use hybrid search for best results
3. Limit results to what you need

### Integration Examples

**JavaScript/Frontend:**
```javascript
const searchCamps = async (query) => {
  const response = await fetch('https://offline.oknotok.com/api/v1/search/hybrid', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      query: query,
      year: 2025,
      types: ['camp'],
      limit: 20
    })
  });
  
  const data = await response.json();
  return data.results;
};
```

**Ruby:**
```ruby
require 'httparty'

response = HTTParty.post(
  'https://offline.oknotok.com/api/v1/search/vector',
  body: {
    query: 'interactive art',
    types: ['art']
  }.to_json,
  headers: { 'Content-Type' => 'application/json' }
)

results = response.parsed_response['results']
```

## Maintenance Commands

```bash
# Import data for a specific year
rails search:import[2025]

# Generate missing embeddings
rails search:generate_embeddings

# Show search statistics
rails search:stats

# Clear all search data
rails search:clear
```

## Cost Estimation

- **Embedding Generation**: ~$0.0004 per 1K tokens
- **Estimated cost per item**: ~$0.002
- **Total for 2000 items**: ~$4.00
- **Search queries**: No additional cost (uses stored embeddings)

## Troubleshooting

### "Failed to generate embedding"
- Check OPENAI_API_KEY is set correctly
- Verify OpenAI API access and quota
- Check Rails logs for detailed error

### Slow search performance
- Ensure pgvector indexes are created
- Check PostgreSQL query performance
- Consider adjusting similarity threshold

### Missing search results
- Verify embeddings are generated (`rails search:stats`)
- Check item has sufficient text content
- Try lowering similarity threshold

---

*Vector Search API v1.0 - Part of the OK-OFFLINE ecosystem*