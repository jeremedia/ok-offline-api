# Neo4j Knowledge Graph Setup

## Overview

We've extracted 500K+ pool entities from the Burning Man dataset using the Seven Pools of Enliteracy. Now we need to import them into Neo4j to create a searchable knowledge graph.

## Setup Status

1. **Neo4j Installation**: ✅ Installed via Homebrew
2. **Neo4j Running**: ✅ Running at pid 40960
3. **Neo4j Services Created**: ✅ 
   - `Neo4jGraphService` - Uses Bolt driver
   - `Neo4jHttpService` - Uses HTTP API
4. **API Endpoints**: ✅ Created at `/api/v1/graph/*`
5. **Authentication**: ❌ Need to configure password

## Next Steps

### 1. Configure Neo4j Authentication

Open http://localhost:7474 in your browser and:
1. Login with username: `neo4j` and password: `neo4j`
2. You'll be prompted to change the password
3. Set it to match your `.env` file or update `.env` with the new password

### 2. Import the Data

Once authentication is configured, run:

```bash
# Import all 500K entities and create relationships
rails neo4j:import

# Check stats after import
rails neo4j:stats

# Test queries
rails neo4j:test
```

### 3. Use the Knowledge Graph

The graph will contain:
- **54,522 Item nodes** (camps, art, events across all years)
- **~50,000 Entity nodes** (unique entities from the pools)
- **500K+ HAS_ENTITY relationships** (connecting items to their pool entities)
- **APPEARS_WITH relationships** (connecting entities that co-occur)

### 4. Query Examples

```ruby
# Find all items related to "fire"
service = Neo4jGraphService.new
service.find_related_items("fire", limit: 10)

# Find entities connected to "fire" 
service.find_entity_connections("fire", max_depth: 2)

# Find items that bridge manifest and experience pools
service.find_pool_bridges("manifest", "experience")
```

### 5. API Usage

```bash
# Get entity connections
curl http://localhost:3555/api/v1/graph/entity/fire

# Find pool bridges
curl "http://localhost:3555/api/v1/graph/bridge?pool1=manifest&pool2=experience"

# Get graph stats
curl http://localhost:3555/api/v1/graph/stats

# Custom Cypher query
curl -X POST http://localhost:3555/api/v1/graph/query \
  -H "Content-Type: application/json" \
  -d '{"query": "MATCH (e:Entity {pool: \"manifest\"})<-[:HAS_ENTITY]-(i:Item) RETURN e.name, COUNT(i) as count ORDER BY count DESC LIMIT 10"}'
```

## Graph Schema

```
(:Item {uid, name, type, year, description, location})
  -[:HAS_ENTITY {pool, confidence}]->
(:Entity {name, pool, occurrence_count})
  -[:APPEARS_WITH {count}]->
(:Entity)
```

## Why Neo4j?

With 500K+ pool entities extracted, Neo4j enables:
- Graph traversal queries (find paths between concepts)
- Pattern matching (find items that share entity patterns)
- Relationship analysis (discover hidden connections)
- Real-time graph queries for the chat interface

This transforms our flat search into a multi-dimensional knowledge graph!