# Seven Pools Ruby Gem Architecture

## Gem Structure: `seven_pools`

```ruby
# seven_pools.gemspec
Gem::Specification.new do |spec|
  spec.name          = "seven_pools"
  spec.version       = "0.1.0"
  spec.summary       = "Multi-dimensional entity extraction framework"
  spec.description   = "Extract semantic entities across seven dimensions for enhanced search and understanding"
  
  spec.add_dependency "openai-ruby", "~> 7.0"
  spec.add_dependency "activerecord", ">= 6.0"
  spec.add_dependency "pg", "~> 1.0"
  spec.add_dependency "solid_queue", "~> 1.0" # For Rails 8+
end
```

## Core Components

### 1. Pool Definitions
```ruby
module SevenPools
  POOLS = {
    manifest: {
      name: "Manifest Pool",
      description: "Physical forms and appearances",
      prompts: {
        default: "Extract physical descriptions, materials, structures...",
        art: "Extract artistic medium, dimensions, physical presence...",
        camp: "Extract camp structures, shade, physical layout..."
      }
    },
    experience: {
      name: "Experience Pool",
      description: "Activities and events",
      prompts: { ... }
    },
    # ... other pools
  }
end
```

### 2. Extraction Service
```ruby
module SevenPools
  class Extractor
    def initialize(api_key: nil, model: "gpt-4.1-nano")
      @client = OpenAI::Client.new(access_token: api_key || ENV['OPENAI_API_KEY'])
      @model = model
    end
    
    def extract(text, context_type: :default)
      # Single item extraction
    end
    
    def batch_extract(items, options = {})
      # Batch extraction with cost optimization
    end
  end
end
```

### 3. Storage Adapter
```ruby
module SevenPools
  module Storage
    class ActiveRecordAdapter
      def store_entities(item_id, pool_entities)
        # Store in your app's database
      end
    end
    
    class PostgresAdapter
      # Direct PostgreSQL storage
    end
    
    class InMemoryAdapter
      # For testing/development
    end
  end
end
```

### 4. Search Interface
```ruby
module SevenPools
  class Search
    def within_pool(pool_name, query)
      # Search within specific pool
    end
    
    def across_pools(query, pools: :all)
      # Multi-pool search
    end
    
    def by_relationship(start_entity, relationship_type)
      # Graph-based search
    end
  end
end
```

### 5. Batch Processing
```ruby
module SevenPools
  class BatchProcessor
    include SevenPools::CostTracking
    
    def process(items, options = {})
      # OpenAI Batch API integration
      # Webhook handling
      # Progress tracking
    end
  end
end
```

## Usage Examples

### Basic Usage
```ruby
require 'seven_pools'

# Initialize extractor
extractor = SevenPools::Extractor.new

# Extract from single item
pools = extractor.extract(
  "Sunrise Yoga Camp offers daily yoga classes at dawn...",
  context_type: :camp
)
# => { 
#   manifest: ["yoga mats", "shade structure"],
#   experience: ["yoga class", "dawn practice"],
#   practical: ["daily schedule", "morning activity"]
# }

# Batch extraction
items = [
  { id: 1, text: "..." },
  { id: 2, text: "..." }
]

batch = SevenPools::BatchProcessor.new
batch.process(items) do |progress|
  puts "Processing: #{progress.completed}/#{progress.total}"
end
```

### Rails Integration
```ruby
# config/initializers/seven_pools.rb
SevenPools.configure do |config|
  config.api_key = ENV['OPENAI_API_KEY']
  config.storage = SevenPools::Storage::ActiveRecordAdapter.new
  config.default_model = "gpt-4.1-nano"
end

# app/models/searchable_item.rb
class SearchableItem < ApplicationRecord
  include SevenPools::Searchable
  
  has_many :pool_entities
  
  after_save :extract_pools_async
end
```

### Rake Tasks
```ruby
# lib/tasks/seven_pools.rake
namespace :seven_pools do
  desc "Extract pools for all items"
  task extract_all: :environment do
    SevenPools::Tasks::ExtractAll.new.run
  end
  
  desc "Search within pools"
  task :search, [:query, :pool] => :environment do |t, args|
    results = SevenPools::Search.new.within_pool(args[:pool], args[:query])
    # ...
  end
end
```

## Cost Management

```ruby
module SevenPools
  module CostTracking
    def estimate_cost(items_count)
      tokens_per_item = 700 # average
      total_tokens = items_count * tokens_per_item
      cost_per_million = 0.20 # gpt-4.1-nano batch
      (total_tokens / 1_000_000.0) * cost_per_million
    end
    
    def track_usage(batch_id, actual_cost)
      # Store in database or monitoring system
    end
  end
end
```

## Testing

```ruby
RSpec.describe SevenPools::Extractor do
  it "extracts entities across all pools" do
    VCR.use_cassette("pool_extraction") do
      result = extractor.extract("Test content")
      
      expect(result).to include(
        manifest: Array,
        experience: Array,
        relational: Array
      )
    end
  end
end
```