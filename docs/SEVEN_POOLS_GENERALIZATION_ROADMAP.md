# Seven Pools Generalization Roadmap

## Overview

The Seven Pools of Enliteracy framework can be generalized into multiple complementary components that work together to provide a comprehensive entity extraction and search ecosystem.

## Proposed Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Applications Layer                       │
├─────────────────┬─────────────────┬────────────────────────┤
│   ChatGPT       │   Custom Apps   │   Research Tools       │
│   Connector     │                 │                        │
└────────┬────────┴────────┬────────┴───────┬────────────────┘
         │                 │                │
┌────────▼────────┐ ┌──────▼──────┐ ┌──────▼──────┐
│   MCP Server    │ │  REST API   │ │  GraphQL    │
│  (Python/Ruby)  │ │  (Rails)    │ │  (Future)   │
└────────┬────────┘ └──────┬──────┘ └──────┬──────┘
         │                 │                │
         └─────────────────┼────────────────┘
                           │
                  ┌────────▼────────┐
                  │  Rails Engine   │
                  │  (seven_pools)  │
                  └────────┬────────┘
                           │
                  ┌────────▼────────┐
                  │   Ruby Gem      │
                  │  (seven_pools)  │
                  └────────┬────────┘
                           │
                  ┌────────▼────────┐
                  │  Core Services  │
                  │  - Extractor    │
                  │  - Batch Proc   │
                  │  - Search       │
                  └─────────────────┘
```

## Implementation Phases

### Phase 1: Ruby Gem (2-3 weeks)
Extract core functionality into a standalone gem.

**Deliverables:**
- [ ] Core pool definitions and framework
- [ ] Single-item extraction service
- [ ] Batch processing with OpenAI Batch API
- [ ] Cost tracking utilities
- [ ] Basic storage adapters (ActiveRecord, PostgreSQL)
- [ ] RSpec test suite
- [ ] Documentation

**Key Files to Extract:**
```ruby
# From current implementation
app/services/search/pool_entity_extraction_service.rb
app/services/search/batch_pool_entity_extraction_service.rb
app/models/batch_job.rb
app/jobs/process_batch_results_job.rb
```

### Phase 2: Rails Engine (2 weeks)
Build mountable engine on top of gem.

**Deliverables:**
- [ ] Mountable engine structure
- [ ] REST API endpoints
- [ ] Background job integration
- [ ] Webhook handling
- [ ] Admin UI (optional)
- [ ] Migration generators
- [ ] Configuration system

### Phase 3: MCP Server (1-2 weeks)
Create MCP server for ChatGPT integration.

**Deliverables:**
- [ ] Python FastMCP implementation
- [ ] Search and fetch tools
- [ ] Real-time extraction tool
- [ ] Relationship exploration
- [ ] OAuth2 authentication
- [ ] Deployment configuration

### Phase 4: Enhanced Features (Ongoing)
Add advanced capabilities.

**Possibilities:**
- [ ] Graph database integration (Neo4j)
- [ ] ML-based entity prediction
- [ ] Visual relationship mapping
- [ ] Community contribution system
- [ ] Multi-language support

## Technical Decisions

### 1. Gem vs Engine
- **Gem**: Core functionality, no Rails dependency
- **Engine**: Rails-specific features, UI, migrations

### 2. Storage Options
```ruby
# Flexible storage adapter pattern
module SevenPools
  module Storage
    class Adapter
      def store_entities(item_id, entities); end
      def fetch_entities(item_id); end
      def search(pool, query); end
    end
  end
end
```

### 3. API Design
```yaml
# RESTful endpoints
GET  /api/v1/search/pools/:pool?q=query
GET  /api/v1/search/cross-pool?q=query
POST /api/v1/extract
POST /api/v1/batch/submit
GET  /api/v1/batch/:id/status

# MCP tools
search(query, pool?)
fetch(id)
analyze_pools(text)
find_relationships(entity, pool)
```

### 4. Cost Optimization
- Batch processing by default
- Caching layer for common queries
- Progressive extraction (on-demand pools)

## Migration Strategy

### From Current Implementation

1. **Extract Services**
```bash
# Create gem structure
bundle gem seven_pools
cd seven_pools

# Copy core services
cp ../api/app/services/search/*pool*.rb lib/seven_pools/
```

2. **Refactor Dependencies**
```ruby
# Before (Rails-specific)
class PoolEntityExtractionService
  include Rails.application.routes.url_helpers
  
# After (Gem-compatible)
class SevenPools::Extractor
  # No Rails dependencies
```

3. **Create Adapters**
```ruby
# For existing Rails apps
class SevenPools::RailsAdapter < SevenPools::Storage::Adapter
  def store_entities(item_id, entities)
    SearchEntity.transaction do
      # Existing storage logic
    end
  end
end
```

## Usage Examples

### Standalone Gem
```ruby
require 'seven_pools'

extractor = SevenPools::Extractor.new(api_key: ENV['OPENAI_API_KEY'])
pools = extractor.extract("Sunrise Yoga Camp offers daily yoga...")
# => { manifest: [...], experience: [...], ... }
```

### Rails Integration
```ruby
# Gemfile
gem 'seven_pools'

# Model
class SearchableItem < ApplicationRecord
  include SevenPools::Extractable
  
  extracts_pools context: :item_type
end

# Controller
def search
  results = SevenPools.search(params[:q], pool: params[:pool])
  render json: results
end
```

### MCP Server Usage
```python
# In ChatGPT or via API
response = mcp_client.call_tool(
    "search",
    {"query": "sustainable camps", "pool": "philosophical"}
)
```

## Documentation Strategy

### 1. Gem Documentation
- README with quick start
- YARD documentation for all classes
- Example implementations
- Migration guide from raw implementation

### 2. API Documentation
- OpenAPI 3.0 specification
- Postman collection
- Authentication guide
- Rate limiting documentation

### 3. MCP Documentation
- Setup guide for ChatGPT
- Security best practices
- Example research queries
- Integration patterns

## Testing Strategy

### 1. Unit Tests (Gem)
```ruby
RSpec.describe SevenPools::Extractor do
  it "extracts entities from text"
  it "handles API errors gracefully"
  it "respects rate limits"
end
```

### 2. Integration Tests (Engine)
```ruby
RSpec.describe "Pool Search API" do
  it "searches within specific pool"
  it "performs cross-pool search"
  it "handles pagination"
end
```

### 3. E2E Tests (MCP)
```python
def test_mcp_search_tool():
    result = server.search("yoga", pool="experience")
    assert "results" in result
    assert len(result["results"]) > 0
```

## Success Metrics

1. **Adoption**
   - Number of gems downloaded
   - Apps using the engine
   - MCP server connections

2. **Performance**
   - Extraction speed (items/minute)
   - Search response time (<100ms)
   - Cost per item (<$0.0002)

3. **Quality**
   - Entity precision/recall
   - User satisfaction scores
   - Community contributions

## Next Steps

1. **Immediate** (This Week)
   - [ ] Create seven_pools gem repository
   - [ ] Extract core services
   - [ ] Write initial tests

2. **Short Term** (Month 1)
   - [ ] Publish gem v0.1.0
   - [ ] Create Rails engine
   - [ ] Deploy MCP server

3. **Long Term** (Months 2-3)
   - [ ] Community feedback integration
   - [ ] Performance optimizations
   - [ ] Additional language support

## Conclusion

The Seven Pools framework has proven valuable for the Burning Man dataset. By generalizing it into reusable components, we can:

1. Enable other communities to build multi-dimensional search
2. Provide researchers with powerful semantic tools
3. Create new possibilities for AI-assisted exploration
4. Build a sustainable open-source project

The modular approach (Gem → Engine → MCP) ensures each component can evolve independently while maintaining compatibility.