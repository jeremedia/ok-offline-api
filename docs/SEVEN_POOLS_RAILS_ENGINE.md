# Seven Pools Rails Engine

## Creating a Mountable Rails Engine

### 1. Engine Structure

```bash
# Generate the engine
rails plugin new seven_pools --mountable --database=postgresql

cd seven_pools
```

### 2. Core Engine Files

```ruby
# seven_pools.gemspec
$:.push File.expand_path("lib", __dir__)

require "seven_pools/version"

Gem::Specification.new do |spec|
  spec.name        = "seven_pools"
  spec.version     = SevenPools::VERSION
  spec.authors     = ["Your Name"]
  spec.email       = ["your.email@example.com"]
  spec.homepage    = "https://github.com/yourusername/seven_pools"
  spec.summary     = "Seven Pools of Enliteracy - Multi-dimensional entity extraction"
  spec.description = "Extract and search semantic entities across seven dimensions"
  spec.license     = "MIT"

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  spec.add_dependency "rails", ">= 7.0"
  spec.add_dependency "pg", "~> 1.0"
  spec.add_dependency "openai-ruby", "~> 7.0"
  spec.add_dependency "solid_queue", "~> 1.0"
  
  spec.add_development_dependency "rspec-rails"
  spec.add_development_dependency "factory_bot_rails"
end
```

### 3. Engine Configuration

```ruby
# lib/seven_pools/engine.rb
module SevenPools
  class Engine < ::Rails::Engine
    isolate_namespace SevenPools
    
    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_bot
      g.factory_bot dir: 'spec/factories'
    end
    
    # Load engine migrations
    initializer :append_migrations do |app|
      unless app.root.to_s.match?(root.to_s)
        config.paths["db/migrate"].expanded.each do |expanded_path|
          app.config.paths["db/migrate"] << expanded_path
        end
      end
    end
    
    # Configuration
    config.seven_pools = ActiveSupport::OrderedOptions.new
    config.seven_pools.api_key = nil
    config.seven_pools.model = "gpt-4.1-nano"
    config.seven_pools.batch_size = 500
    config.seven_pools.webhook_secret = nil
  end
end

# lib/seven_pools.rb
require "seven_pools/version"
require "seven_pools/engine"

module SevenPools
  # Pool definitions
  POOLS = {
    manifest: {
      name: "Manifest Pool",
      description: "Physical forms, appearances, materials"
    },
    experience: {
      name: "Experience Pool", 
      description: "Activities, events, what participants can do"
    },
    relational: {
      name: "Relational Pool",
      description: "Connections, associations, relationships"
    },
    philosophical: {
      name: "Philosophical Pool",
      description: "Concepts, meanings, deeper themes"
    },
    practical: {
      name: "Practical Pool",
      description: "Utility, function, practical offerings"
    },
    collective: {
      name: "Collective Pool",
      description: "Community significance, shared experiences"
    },
    interface: {
      name: "Interface Pool",
      description: "How things are accessed or interacted with"
    }
  }
  
  mattr_accessor :configuration
  self.configuration = ActiveSupport::OrderedOptions.new
  
  def self.configure
    yield(configuration)
  end
end
```

### 4. Models

```ruby
# app/models/seven_pools/pool_entity.rb
module SevenPools
  class PoolEntity < ApplicationRecord
    self.table_name = "seven_pools_entities"
    
    belongs_to :poolable, polymorphic: true
    
    validates :pool_type, inclusion: { in: POOLS.keys.map(&:to_s) }
    validates :entity_value, presence: true
    
    scope :in_pool, ->(pool) { where(pool_type: pool.to_s) }
    scope :search, ->(query) { where("entity_value ILIKE ?", "%#{query}%") }
    
    def pool_name
      POOLS[pool_type.to_sym][:name]
    end
  end
end

# app/models/seven_pools/batch_job.rb
module SevenPools
  class BatchJob < ApplicationRecord
    self.table_name = "seven_pools_batch_jobs"
    
    enum status: {
      pending: "pending",
      validating: "validating", 
      in_progress: "in_progress",
      finalizing: "finalizing",
      completed: "completed",
      failed: "failed",
      cancelled: "cancelled",
      expired: "expired"
    }
    
    def duration_in_words
      return nil unless completed_at && created_at
      distance_of_time_in_words(created_at, completed_at)
    end
  end
end
```

### 5. Services

```ruby
# app/services/seven_pools/extractor.rb
module SevenPools
  class Extractor
    attr_reader :client, :model
    
    def initialize(api_key: nil, model: nil)
      @client = OpenAI::Client.new(
        access_token: api_key || SevenPools.configuration.api_key
      )
      @model = model || SevenPools.configuration.model
    end
    
    def extract(text, context: {})
      prompt = build_prompt(text, context)
      
      response = client.chat(
        parameters: {
          model: model,
          messages: [
            { role: "system", content: prompt[:system] },
            { role: "user", content: text }
          ],
          response_format: { type: "json_object" }
        }
      )
      
      parse_extraction(response)
    end
    
    private
    
    def build_prompt(text, context)
      # Build context-aware prompts
    end
    
    def parse_extraction(response)
      # Parse OpenAI response
    end
  end
end

# app/services/seven_pools/batch_processor.rb
module SevenPools
  class BatchProcessor
    include ActiveSupport::Rescuable
    
    def submit_batch(items, options = {})
      validate_items!(items)
      
      batches = items.in_groups_of(SevenPools.configuration.batch_size, false)
      batch_jobs = []
      
      batches.each_with_index do |batch_items, index|
        file = create_batch_file(batch_items, index)
        batch_job = submit_to_openai(file, batch_items)
        batch_jobs << batch_job
      end
      
      batch_jobs
    end
  end
end
```

### 6. Controllers

```ruby
# app/controllers/seven_pools/api/v1/base_controller.rb
module SevenPools
  module Api
    module V1
      class BaseController < ActionController::API
        before_action :authenticate_api_key
        
        private
        
        def authenticate_api_key
          # API key authentication
        end
      end
    end
  end
end

# app/controllers/seven_pools/api/v1/search_controller.rb
module SevenPools
  module Api
    module V1
      class SearchController < BaseController
        def pool
          results = PoolEntity
            .in_pool(params[:pool])
            .search(params[:q])
            .includes(:poolable)
            .limit(params[:limit] || 20)
            
          render json: {
            results: serialize_results(results),
            pool: params[:pool],
            total: results.count
          }
        end
        
        def cross_pool
          results = {}
          
          POOLS.keys.each do |pool|
            results[pool] = PoolEntity
              .in_pool(pool)
              .search(params[:q])
              .limit(5)
              .pluck(:entity_value)
          end
          
          render json: { results: results, query: params[:q] }
        end
      end
    end
  end
end
```

### 7. Background Jobs

```ruby
# app/jobs/seven_pools/process_batch_job.rb
module SevenPools
  class ProcessBatchJob < ApplicationJob
    queue_as :seven_pools
    
    def perform(batch_id)
      batch = BatchJob.find(batch_id)
      processor = BatchResultProcessor.new
      
      processor.process(batch)
    end
  end
end
```

### 8. Migrations

```ruby
# db/migrate/001_create_seven_pools_tables.rb
class CreateSevenPoolsTables < ActiveRecord::Migration[7.0]
  def change
    create_table :seven_pools_entities do |t|
      t.references :poolable, polymorphic: true, null: false
      t.string :pool_type, null: false
      t.string :entity_value, null: false
      t.float :confidence
      t.jsonb :metadata
      t.timestamps
      
      t.index [:pool_type, :entity_value]
      t.index [:poolable_type, :poolable_id]
    end
    
    create_table :seven_pools_batch_jobs do |t|
      t.string :batch_id, null: false
      t.string :status, default: "pending"
      t.integer :total_items
      t.string :input_file_id
      t.string :output_file_id
      t.string :error_file_id
      t.decimal :estimated_cost, precision: 10, scale: 4
      t.decimal :total_cost, precision: 10, scale: 4
      t.jsonb :metadata
      t.timestamps
      
      t.index :batch_id, unique: true
      t.index :status
    end
  end
end
```

### 9. Mountable Routes

```ruby
# config/routes.rb
SevenPools::Engine.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :extractions, only: [:create]
      
      resources :search, only: [] do
        collection do
          get :pool
          get :cross_pool
          get :relationships
        end
      end
      
      resources :batches, only: [:create, :show] do
        member do
          post :process_results
        end
      end
      
      post "webhooks/openai", to: "webhooks#openai"
    end
  end
  
  # Admin UI (optional)
  namespace :admin do
    resources :pool_entities
    resources :batch_jobs
    root to: "dashboard#index"
  end
end
```

### 10. Integration in Host App

```ruby
# Gemfile
gem 'seven_pools', github: 'yourusername/seven_pools'

# config/routes.rb
Rails.application.routes.draw do
  mount SevenPools::Engine => "/seven_pools"
end

# config/initializers/seven_pools.rb
SevenPools.configure do |config|
  config.api_key = ENV['OPENAI_API_KEY']
  config.webhook_secret = ENV['OPENAI_WEBHOOK_SECRET']
  config.model = "gpt-4.1-nano"
  config.batch_size = 500
end

# app/models/searchable_item.rb
class SearchableItem < ApplicationRecord
  # Include Seven Pools functionality
  has_many :pool_entities, 
    as: :poolable, 
    class_name: "SevenPools::PoolEntity",
    dependent: :destroy
    
  def extract_pools!
    extractor = SevenPools::Extractor.new
    results = extractor.extract(searchable_text, context: { type: item_type })
    
    results.each do |pool, entities|
      entities.each do |entity|
        pool_entities.find_or_create_by(
          pool_type: pool,
          entity_value: entity
        )
      end
    end
  end
end
```

### 11. Rake Tasks

```ruby
# lib/tasks/seven_pools_tasks.rake
namespace :seven_pools do
  desc "Extract pools for all items"
  task extract_all: :environment do
    items = SearchableItem.where.missing(:pool_entities)
    
    processor = SevenPools::BatchProcessor.new
    batch_jobs = processor.submit_batch(items)
    
    puts "Submitted #{batch_jobs.count} batches"
    puts "Total items: #{items.count}"
    puts "Estimated cost: $#{'%.2f' % processor.estimate_cost(items.count)}"
  end
  
  desc "Pool statistics"
  task stats: :environment do
    POOLS.keys.each do |pool|
      count = SevenPools::PoolEntity.in_pool(pool).count
      unique = SevenPools::PoolEntity.in_pool(pool).distinct.count(:entity_value)
      
      puts "#{pool.to_s.capitalize}: #{count} total, #{unique} unique"
    end
  end
end
```

## Benefits of Rails Engine Approach

1. **Modular**: Drop into any Rails app
2. **Configurable**: Each app can customize settings
3. **Testable**: Isolated test suite
4. **Versioned**: Semantic versioning for updates
5. **Documented**: YARD documentation support
6. **API-Ready**: Built-in REST endpoints
7. **Background Jobs**: Solid Queue integration
8. **Admin UI**: Optional admin interface

## Usage Example

```ruby
# In your Rails app
item = SearchableItem.find(123)

# Extract pools for single item
item.extract_pools!

# Search within pools
results = SevenPools::PoolEntity
  .in_pool(:experience)
  .search("yoga")
  .includes(:poolable)

# Batch extraction
items = SearchableItem.limit(1000)
SevenPools::BatchProcessor.new.submit_batch(items)
```