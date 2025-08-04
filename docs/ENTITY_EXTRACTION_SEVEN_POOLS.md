# Seven Pools Entity Extraction Implementation

## Overview
We've enhanced the entity extraction system to implement the Seven Pools of Enliteracy framework, enabling the dataset to understand multi-dimensional meaning across philosophical, physical, experiential, and other pools.

## Implementation Details

### 1. BatchEntityExtractionService
**File**: `app/services/search/batch_entity_extraction_service.rb`

Key features:
- Uses OpenAI Batch API for 50% cost savings
- Extracts traditional entities (locations, activities, themes, times, people)
- Extracts pool-specific entities for all seven pools
- Identifies cross-pool flows (e.g., how an idea manifests physically)
- Processes results via webhook for async operation

### 2. Enhanced Entity Types

**Traditional Entities** (backwards compatible):
- `location` - BRC addresses, plaza names, camps
- `activity` - Workshops, performances, services
- `theme` - Art themes, camp concepts
- `time` - Time references
- `person` - Notable people mentioned

**Pool-Specific Entities** (new):
- `pool_idea` - Principles, philosophical concepts, cultural values
- `pool_manifest` - Physical structures, art pieces, tangible offerings
- `pool_experience` - Emotions, transformative moments, sensory descriptions
- `pool_relational` - Collaborations, communities, connections
- `pool_evolutionary` - Historical references, changes, innovations
- `pool_practical` - Skills taught, techniques, how-to elements
- `pool_emanation` - Broader impacts, influences beyond BRC

**Cross-Pool Flows** (new):
- `flow` - Connections between pools with metadata for from/to pools

### 3. Integration Points

**BatchCompletionJob** (`app/jobs/batch_completion_job.rb`):
- Updated to handle both embeddings and entity extraction
- Routes to appropriate processor based on `task_type`

**WebhooksController** (`app/controllers/api/v1/webhooks_controller.rb`):
- Handles OpenAI batch completion webhooks
- Triggers BatchCompletionJob for async processing

## Usage

### Test with Small Batch
```ruby
# Find items without entities
items = SearchableItem.left_joins(:search_entities)
                     .where(search_entities: { id: nil })
                     .limit(5)

# Create batch job
service = Search::BatchEntityExtractionService.new
result = service.queue_batch_extraction(items, description: "Test batch")

# Check status
client = OpenAI::Client.new
batch = client.batches.retrieve(id: result[:openai_batch_id])
puts batch['status']
```

### Process All Items
```bash
# Run the full extraction (48,487 items)
ruby process_all_entities_batch.rb
```

### Check Results
```ruby
# Check pool entities
SearchEntity.where('entity_type LIKE ?', 'pool_%').count

# Check flows
SearchEntity.where(entity_type: 'flow').count

# Find items embodying specific principle
SearchEntity.where(entity_type: 'pool_idea', entity_value: 'radical inclusion')
            .includes(:searchable_item)
            .map(&:searchable_item)
```

## Example Enhanced Entity Extraction

For a camp like "Space Punks":
```json
{
  "traditional": {
    "locations": ["7:30 & C"],
    "activities": ["dance party", "light show"],
    "themes": ["space", "punk", "rebellion"]
  },
  "pools": {
    "idea": ["radical self-expression", "immediacy"],
    "manifest": ["LED costumes", "sound system", "dance floor"],
    "experience": ["transformation through dance", "cosmic connection"],
    "relational": ["punk community", "dance collective"],
    "evolutionary": ["evolved from small sound camp"],
    "practical": ["LED programming workshops"],
    "emanation": ["inspired regional space-themed events"]
  },
  "cross_pool_flows": [
    {
      "from_pool": "idea",
      "to_pool": "manifest",
      "concept": "radical self-expression manifests as LED costumes"
    }
  ]
}
```

## Next Steps

1. **Complete extraction for all 48,487 items** - Run `process_all_entities_batch.rb`
2. **Build multi-pool search endpoints** - Enable queries across pools
3. **Create flow visualization** - Show how concepts travel between pools
4. **Import more pool-specific content** - Especially Experience and Emanation pools

## Monitoring

Check extraction progress:
```bash
# Total entities by pool
rails runner "
pools = %w[idea manifest experience relational evolutionary practical emanation]
pools.each do |pool|
  count = SearchEntity.where(entity_type: \"pool_#{pool}\").count
  puts \"#{pool.capitalize} Pool: #{count}\"
end
"

# Items with enhanced entities
rails runner "
with_pools = SearchableItem.joins(:search_entities)
                          .where('search_entities.entity_type LIKE ?', 'pool_%')
                          .distinct.count
puts \"Items with pool entities: #{with_pools}\"
"
```

## Cost Optimization

Using the Batch API provides:
- 50% discount on API costs
- Async processing (24-hour window)
- Webhook notifications
- Automatic retry on failures

For 48,487 items, this saves approximately $24 in API costs compared to synchronous processing.