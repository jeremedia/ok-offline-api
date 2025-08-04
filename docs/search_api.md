# Vector Search API Documentation

## Overview

AI-powered semantic search for Burning Man camps, art, and events. Uses OpenAI embeddings to understand intent and find relevant results even when exact keywords don't match.

## Endpoints

### 1. Vector Search (Semantic)

**POST** `/api/v1/search/vector`

Pure semantic search using AI embeddings.

#### Request
```json
{
  "query": "where can I find ice cream",
  "year": 2024,
  "limit": 20
}
```

#### Response
```json
{
  "results": [
    {
      "id": 123,
      "name": "Frozen Oasis",
      "description": "Serving frozen treats and cold desserts",
      "location": "7:30 & Esplanade",
      "category": "camp",
      "score": 0.92,
      "year": 2024
    }
  ],
  "query_info": {
    "original_query": "where can I find ice cream",
    "total_results": 15,
    "search_type": "vector"
  }
}
```

### 2. Hybrid Search

**POST** `/api/v1/search/hybrid`

Combines keyword matching with semantic search for best results.

#### Request
```json
{
  "query": "techno music camps",
  "year": 2024,
  "limit": 20
}
```

### 3. Autocomplete Suggestions

**POST** `/api/v1/search/suggest`

Get autocomplete suggestions based on partial input.

#### Request
```json
{
  "query": "burn",
  "year": 2024,
  "limit": 10
}
```

#### Response
```json
{
  "suggestions": [
    {
      "id": 456,
      "name": "Burning Band",
      "category": "camp",
      "location": "3:00 & A"
    }
  ]
}
```

## Request Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| query | string | Yes | - | Search query text |
| year | integer | No | 2024 | Event year |
| limit | integer | No | 20 | Max results (1-100) |

## Response Fields

### Result Object

| Field | Type | Description |
|-------|------|-------------|
| id | integer | Unique identifier |
| name | string | Entity name |
| description | string | Full description |
| location | string | Camp/art location |
| category | string | Type: camp, art, event |
| score | float | Relevance score (0-1) |
| year | integer | Event year |

## Search Categories

- `camp` - Theme camps
- `art` - Art installations
- `event` - Scheduled events

## Example Usage

### Smart Queries

The vector search understands intent:
- "cold drinks" → finds bars and beverage camps
- "need coffee" → finds coffee camps
- "electronic music" → finds techno/house camps
- "interactive art" → finds participatory installations

### JavaScript Example
```javascript
// Semantic search
const response = await fetch('/api/v1/search/vector', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    query: 'places to cool down',
    year: 2024
  })
});

const results = await response.json();
// Returns camps with AC, misting, shade, etc.
```

## Environment Setup

### Required Environment Variables

```bash
# OpenAI Configuration
OPENAI_API_KEY=your_openai_api_key
```

### Database Setup

```bash
# Enable pgvector extension
rails db -c "CREATE EXTENSION IF NOT EXISTS vector;"

# Import and index data
rails search:import[2024]

# Check indexing status
rails search:stats
```

## Performance

- Vector search: ~100-300ms
- Hybrid search: ~150-400ms
- Autocomplete: ~50-150ms

Results are ranked by semantic similarity, with scores from 0-1 indicating relevance.

## Rate Limiting

Currently no rate limiting. Recommended limits:
- 100 requests/minute per IP
- 1000 requests/hour per IP