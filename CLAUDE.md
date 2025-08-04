# API Service - CLAUDE.md

Rails 8 API service for the OK-OFFLINE ecosystem.

## IMPORTANT: OpenAI Ruby SDK Update (August 2025)

**CRITICAL**: The OpenAI Ruby SDK (`openai` gem) version 0.16.0 is the CURRENT version as of July 30, 2025, NOT an old version.

This version INCLUDES full support for:
- **Responses API** with streaming (`openai.responses.create` and `openai.responses.stream`)
- **Model Context Protocol (MCP)** integration for remote tool access
- **Previous response ID** for conversation continuity
- **Structured outputs** and function calling
- **SSE streaming** for real-time responses

DO NOT assume this is an outdated version. The gem follows a different versioning scheme than expected.

## CRITICAL DEVELOPMENT RULES

### ⚠️  NEVER CHANGE EMBEDDING MODELS ⚠️
**The database contains 51,391 embeddings generated with `text-embedding-3-small`.**

**File**: `app/services/search/embedding_service.rb`
**Current Model**: `EMBEDDING_MODEL = "text-embedding-3-small"`

**DO NOT CHANGE THIS MODEL** for any reason:
- Changing models breaks vector similarity search for ALL existing data
- The database has been enliterated with 51,391 embeddings using this specific model
- Vector embeddings from different models are incompatible (different vector spaces)
- Claude Code has a tendency to change models to names from training data - DO NOT DO THIS

**If you absolutely must change models:**
1. Create a migration script to regenerate ALL 51,391 embeddings
2. Expect significant OpenAI API costs (~$300-500)
3. Plan for several hours of processing time
4. Test thoroughly before deploying

## Development Setup

```bash
bundle install
rails db:setup
rails db -c "CREATE EXTENSION IF NOT EXISTS vector;"
rails server -b 0.0.0.0 -p 3555
```

## Key Services

### Vector Search (Seven Pools of Enliteracy)
- **EmbeddingService**: Generates embeddings with `text-embedding-3-small`
- **VectorSearchService**: Semantic similarity search
- **UnifiedSearchService**: Combines keyword + vector + graph search
- **EntityExtractionService**: Extracts semantic entities from content

### MCP Server (Model Context Protocol)
- **McpController**: SSE-based JSON-RPC server
- **SearchTool**: Vector search via MCP
- **AnalyzePoolsTool**: Real-time enliteracy analysis
- **FetchTool**: Content retrieval and analysis
- **PoolBridgeTool**: Cross-pool entity bridging

### Background Processing
- **Solid Queue**: Background job processing
- **BatchEmbeddingService**: Cost-efficient OpenAI Batch API
- **EntityExtractionService**: Async entity extraction

## Database

- **PostgreSQL** with **pgvector** extension
- **SearchableItems**: 51,391 items with embeddings
- **SearchEntities**: Extracted semantic entities
- **BurningManYears**: Historical Burning Man data structure

## API Endpoints

- `POST /api/v1/search/vector` - Semantic search
- `POST /api/v1/search/hybrid` - Combined search modes
- `POST /api/v1/weather/current` - Weather data
- `GET /api/v1/mcp/sse` - MCP server connection

## Testing Commands

```bash
# Test vector search
rails console
> SearchableItem.where(year: 2017).nearest_neighbors(:embedding, embedding_vector).limit(5)

# Test MCP server
curl -N http://localhost:3555/api/v1/mcp/sse

# Check database stats
rails search:stats
```

## Environment Variables

```bash
OPENAI_API_KEY=sk-...        # Required for embeddings
APPLE_WEATHER_KIT_KEY_ID=... # Weather service
NEO4J_URL=...               # Graph database (optional)
```

Remember: This API serves the enliterated dataset that powers semantic search across 51,391 Burning Man items. The embedding model is locked to preserve data integrity.