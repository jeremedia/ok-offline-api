# Seven Pools MCP Server Architecture

## Overview

An MCP (Model Context Protocol) server that exposes the Seven Pools framework for deep research, allowing ChatGPT and other AI systems to search and analyze multi-dimensional entity relationships.

## Related GitHub Issues

- **Frontend**: [jeremedia/ok-offline#45](https://github.com/jeremedia/ok-offline/issues/45) - Interactive Knowledge Graph Visualization for Seven Pools (mentions API issue #11)
- **API**: Issue #11 - MCP Server Implementation (referenced in frontend issue)

## Server Implementation

### Core MCP Tools

```python
"""
Seven Pools MCP Server
Provides deep research capabilities across the Seven Pools of Enliteracy
"""

from fastmcp import FastMCP
import psycopg2
from typing import Dict, List, Any
import os

# Initialize MCP server
mcp = FastMCP(
    name="Seven Pools Research Server",
    instructions="""
    This server provides access to the Seven Pools of Enliteracy framework.
    Use search to find entities within specific pools or across all pools.
    Use fetch to get detailed information about specific items and their pool relationships.
    """
)

@mcp.tool()
async def search(query: str, pool: str = None) -> Dict[str, List[Dict[str, Any]]]:
    """
    Search for entities within the Seven Pools framework.
    
    Args:
        query: Natural language search query
        pool: Optional - specific pool to search within (manifest, experience, relational, etc.)
        
    Returns:
        Dictionary with search results organized by pool
    """
    
    if pool:
        # Search within specific pool
        results = search_single_pool(query, pool)
    else:
        # Search across all pools
        results = search_all_pools(query)
    
    return {
        "results": results,
        "pools_searched": [pool] if pool else ALL_POOLS,
        "total_matches": len(results)
    }

@mcp.tool()
async def fetch(id: str) -> Dict[str, Any]:
    """
    Fetch complete pool entity information for an item.
    
    Args:
        id: Unique identifier for the item
        
    Returns:
        Complete item data with all pool entities
    """
    
    item = fetch_item_from_db(id)
    pool_entities = fetch_pool_entities(id)
    
    return {
        "id": id,
        "title": item["name"],
        "text": item["description"],
        "url": f"https://offline.oknotok.com/item/{id}",
        "pools": {
            "manifest": pool_entities.get("pool_manifest", []),
            "experience": pool_entities.get("pool_experience", []),
            "relational": pool_entities.get("pool_relational", []),
            "philosophical": pool_entities.get("pool_philosophical", []),
            "practical": pool_entities.get("pool_practical", []),
            "collective": pool_entities.get("pool_collective", []),
            "interface": pool_entities.get("pool_interface", [])
        },
        "metadata": {
            "item_type": item["item_type"],
            "year": item["year"],
            "location": item.get("location_string")
        }
    }

@mcp.tool()
async def analyze_pools(text: str) -> Dict[str, List[str]]:
    """
    Extract pool entities from new text in real-time.
    Useful for analyzing content not yet in the database.
    
    Args:
        text: Text content to analyze
        
    Returns:
        Extracted entities organized by pool
    """
    
    # Real-time extraction using the Seven Pools framework
    entities = await extract_pool_entities(text)
    
    return {
        "manifest": entities.get("manifest", []),
        "experience": entities.get("experience", []),
        "relational": entities.get("relational", []),
        "philosophical": entities.get("philosophical", []),
        "practical": entities.get("practical", []),
        "collective": entities.get("collective", []),
        "interface": entities.get("interface", [])
    }

@mcp.tool()
async def find_relationships(entity: str, pool: str) -> Dict[str, Any]:
    """
    Find relationships between entities across pools.
    Enables graph-based exploration of the dataset.
    
    Args:
        entity: Entity value to search for
        pool: Pool where the entity exists
        
    Returns:
        Related entities and items
    """
    
    # Find all items containing this entity
    items = find_items_with_entity(entity, pool)
    
    # Find related entities in other pools
    related = {}
    for item_id in items:
        item_pools = fetch_pool_entities(item_id)
        for p, entities in item_pools.items():
            if p != pool:
                related[p] = related.get(p, set())
                related[p].update(entities)
    
    return {
        "entity": entity,
        "source_pool": pool,
        "appears_in": len(items),
        "related_entities": {k: list(v) for k, v in related.items()},
        "example_items": items[:5]  # First 5 examples
    }
```

### Advanced Research Tools

```python
@mcp.tool()
async def pool_statistics(year: int = None) -> Dict[str, Any]:
    """
    Get statistics about pool entity distribution.
    Useful for understanding dataset characteristics.
    """
    
    stats = calculate_pool_statistics(year)
    
    return {
        "total_items": stats["item_count"],
        "total_entities": stats["entity_count"],
        "pools": {
            pool: {
                "unique_entities": stats[f"{pool}_unique"],
                "total_occurrences": stats[f"{pool}_total"],
                "top_entities": stats[f"{pool}_top_10"]
            }
            for pool in ALL_POOLS
        },
        "year": year or "all"
    }

@mcp.tool()
async def semantic_bridge(pool1: str, pool2: str, limit: int = 10) -> List[Dict]:
    """
    Find items that bridge two pools with strong entities in both.
    Useful for finding conceptual connections.
    """
    
    bridges = find_pool_bridges(pool1, pool2, limit)
    
    return [
        {
            "id": item["id"],
            "name": item["name"],
            pool1 + "_entities": item[f"pool_{pool1}"],
            pool2 + "_entities": item[f"pool_{pool2}"],
            "bridge_strength": item["strength"]
        }
        for item in bridges
    ]
```

## Deployment Architecture

### 1. Standalone Python/FastMCP Server
```yaml
# docker-compose.yml
version: '3.8'
services:
  seven-pools-mcp:
    build: .
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgresql://...
      - OPENAI_API_KEY=${OPENAI_API_KEY}
    depends_on:
      - postgres
      
  postgres:
    image: pgvector/pgvector:pg16
    environment:
      - POSTGRES_DB=seven_pools
```

### 2. Ruby Implementation (using Rails)
```ruby
# app/services/mcp_server.rb
class SevenPoolsMcpServer
  include ActiveSupport::Rescuable
  
  def search(params)
    query = params[:query]
    pool = params[:pool]
    
    if pool.present?
      results = SearchEntity
        .where(entity_type: "pool_#{pool}")
        .joins(:searchable_item)
        .where("entity_value ILIKE ?", "%#{query}%")
        .limit(20)
    else
      results = SearchEntity
        .joins(:searchable_item)
        .where("entity_value ILIKE ?", "%#{query}%")
        .limit(20)
    end
    
    format_search_results(results)
  end
  
  def fetch(params)
    item = SearchableItem.find(params[:id])
    pool_entities = item.search_entities
      .where("entity_type LIKE 'pool_%'")
      .group_by(&:entity_type)
    
    {
      id: item.id,
      title: item.name,
      text: item.description,
      pools: format_pool_entities(pool_entities),
      metadata: {
        item_type: item.item_type,
        year: item.year
      }
    }
  end
end
```

## Use Cases in ChatGPT

### 1. Deep Research Queries
```
User: "Find all camps that combine yoga (experience) with 
sustainable practices (philosophical)"

ChatGPT uses MCP server:
→ search(pool: "experience", query: "yoga")
→ find_relationships(entity: "yoga", pool: "experience")
→ Filter results for philosophical pool containing "sustainable"
```

### 2. Conceptual Exploration
```
User: "What physical structures (manifest) are associated 
with gift economy practices (collective)?"

ChatGPT uses MCP server:
→ semantic_bridge(pool1: "manifest", pool2: "collective")
→ Analyze patterns in results
```

### 3. Real-time Analysis
```
User: "Analyze this camp description for pool entities:
'Our solar-powered camp offers daily meditation...'"

ChatGPT uses MCP server:
→ analyze_pools(text: "Our solar-powered camp...")
→ Returns extracted entities across all pools
```

## Security & Performance

### Authentication
```python
@mcp.middleware
async def authenticate(request):
    """OAuth2 authentication for MCP requests"""
    token = request.headers.get("Authorization")
    if not validate_token(token):
        raise UnauthorizedError()
```

### Rate Limiting
```python
@mcp.middleware
async def rate_limit(request):
    """Prevent abuse of real-time extraction"""
    key = f"mcp:{request.client_id}"
    if redis.incr(key) > 1000:  # 1000 requests/hour
        raise RateLimitError()
    redis.expire(key, 3600)
```

### Caching
```python
@cache(ttl=3600)  # 1 hour cache
async def search_all_pools(query: str):
    """Cached pool searches for common queries"""
    # Implementation
```

## Integration Benefits

1. **ChatGPT Integration**
   - Direct access to Seven Pools data in conversations
   - Deep research across multiple dimensions
   - Real-time entity extraction for new content

2. **API Access**
   - Programmatic access to pool data
   - Bulk analysis capabilities
   - Integration with other AI systems

3. **Research Applications**
   - Academic study of Burning Man culture
   - Trend analysis across years
   - Community connection mapping

## Future Enhancements

1. **Visual Pool Representations**
   - Graph visualizations of entity relationships
   - Heat maps of pool density by location
   - Timeline views of pool evolution

2. **Collaborative Pool Building**
   - User-suggested entities
   - Community validation
   - Pool entity voting

3. **Advanced Analytics**
   - ML-based pool prediction
   - Anomaly detection in pool patterns
   - Recommendation engine based on pool profiles