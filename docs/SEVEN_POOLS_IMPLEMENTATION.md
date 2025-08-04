# Seven Pools of Enliteracy Implementation

This document describes the implementation of the Seven Pools framework in the OK-OFFLINE API.

## Overview

The Seven Pools of Enliteracy is a framework for extracting multi-dimensional entities from text, enabling more nuanced and contextual search capabilities. Each "pool" represents a different dimension of meaning that can be extracted from Burning Man camps, art, and events.

## The Seven Pools

### 1. Manifest Pool
Physical forms, appearances, and material aspects.
- Examples: "geodesic dome", "LED lights", "shipping container", "art car"

### 2. Experience Pool  
Activities, events, and what participants can do.
- Examples: "yoga class", "DJ set", "workshop", "meditation"

### 3. Relational Pool
Connections, associations, and relationships.
- Examples: "couples", "solo travelers", "families", "queer-friendly"

### 4. Philosophical Pool
Concepts, meanings, and deeper themes.
- Examples: "radical self-expression", "sustainability", "transformation"

### 5. Practical Pool
Utility, function, and practical offerings.
- Examples: "bike repair", "water station", "shade structure", "charging station"

### 6. Collective Pool
Community significance and shared experiences.
- Examples: "sunrise ceremony", "communal kitchen", "gift economy"

### 7. Interface Pool
How things are accessed or interacted with.
- Examples: "open 24/7", "by appointment", "interactive installation"

## Implementation Details

### Service Architecture

```
Search::PoolEntityExtractionService
├── Single item extraction
├── Uses GPT-4.1-nano for cost efficiency
└── Returns JSON with pool arrays

Search::BatchPoolEntityExtractionService  
├── Batch processing (up to 10,000 items)
├── 50% cost savings via OpenAI Batch API
├── Webhook integration for completion
└── Automatic result processing

ProcessBatchResultsJob
├── Background job via Solid Queue
├── Triggered by webhook
└── Processes and stores results
```

### Database Schema

```ruby
# SearchEntity model stores pool entities
SearchEntity
- searchable_item_id: references item
- entity_type: "pool_manifest", "pool_experience", etc.
- entity_value: extracted value
- confidence: float (future use)

# BatchJob tracks batch processing
BatchJob
- batch_id: OpenAI batch identifier
- status: pending/completed/failed
- total_items: count
- estimated_cost: decimal
- total_cost: decimal (actual)
- metadata: JSONB
```

### Cost Structure

- **Model**: GPT-4.1-nano
- **Pricing**: $0.20 per 1M tokens (both input and output)
- **Batch Discount**: 50% off standard pricing
- **Average Usage**: ~700 tokens per item
- **Cost per Item**: ~$0.00014 (with batch discount)

### Extraction Process

1. **Batch Creation**
   ```ruby
   # Items are grouped into batches of 10,000
   service = Search::BatchPoolEntityExtractionService.new
   batch_ids = service.submit_batch_extraction(items)
   ```

2. **File Format**
   ```jsonl
   {"custom_id": "pool_extract_123", "method": "POST", "url": "/v1/chat/completions", "body": {...}}
   {"custom_id": "pool_extract_124", "method": "POST", "url": "/v1/chat/completions", "body": {...}}
   ```

3. **Webhook Processing**
   - OpenAI sends webhook when batch completes
   - Signature verified using Standard Webhooks spec
   - ProcessBatchResultsJob queued automatically

4. **Result Storage**
   - Pool entities extracted from JSON response
   - Stored as SearchEntity records
   - Linked to original SearchableItem

### Usage in Search

Pool entities enhance search in multiple ways:

1. **Direct Pool Search** (future)
   ```ruby
   # Find all camps with yoga activities
   SearchEntity.where(entity_type: 'pool_experience', entity_value: 'yoga')
   ```

2. **Multi-Pool Queries** (future)
   ```ruby
   # Find sustainable art installations
   philosophical = ['sustainability', 'eco-friendly']
   manifest = ['art installation', 'sculpture']
   ```

3. **Enhanced Embeddings** (future)
   - Pool entities can be concatenated to searchable_text
   - Improves semantic search accuracy

## Monitoring and Management

### Rake Tasks

```bash
# Extract pools for all items
rails pools:extract_all

# Extract for specific year
rails pools:extract[2024]

# Check extraction status
rails pools:status

# View batch processing status
rails batches:status

# Calculate costs
rails batches:costs
```

### Monitoring Scripts

```bash
# Monitor batch progress
./test/batch_processing/monitor_batch_4.sh

# Verify automation
ruby test/batch_processing/verify_automation.rb
```

## Best Practices

1. **Batch Size**: Keep batches under 10,000 items for reliability
2. **Error Handling**: Failed items logged to error_file_id
3. **Idempotency**: Re-running extraction overwrites existing entities
4. **Cost Control**: Monitor with BatchJob.sum(:total_cost)

## Future Enhancements

1. **Pool-Specific Search Endpoints**
   - `/api/v1/search/pools/experience`
   - `/api/v1/search/pools/manifest`

2. **Pool Relationships**
   - Graph connections between pools
   - Weighted pool significance

3. **Dynamic Pool Extraction**
   - Real-time extraction for new content
   - User-contributed pool suggestions

4. **Pool Analytics**
   - Most common entities per pool
   - Pool distribution by item type
   - Trending pool entities by year

## Conclusion

The Seven Pools implementation transforms the Burning Man dataset from simple text search to a multi-dimensional knowledge graph. This enables participants to find camps and art based on deeper meaning, activities, relationships, and practical needs - not just keywords.