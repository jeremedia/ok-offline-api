class CreateVectorSearchTables < ActiveRecord::Migration[8.0]
  def change
    # Enable pgvector extension
    enable_extension 'vector'
    
    # Main searchable items table
    create_table :searchable_items do |t|
      t.string :uid, null: false
      t.string :item_type, null: false # 'camp', 'art', 'event'
      t.integer :year, null: false
      t.string :name, null: false
      t.text :description
      t.text :searchable_text # concatenated search content
      t.vector :embedding, limit: 1536 # OpenAI ada-002 dimensions
      t.json :metadata # original item data
      t.timestamps
      
      # Indexes for performance
      t.index :uid, unique: true
      t.index [:item_type, :year]
      t.index :name
    end
    
    # Add vector similarity index after table creation
    add_index :searchable_items, :embedding, using: :hnsw, opclass: :vector_cosine_ops
    
    # Extracted entities table
    create_table :search_entities do |t|
      t.references :searchable_item, foreign_key: true
      t.string :entity_type, null: false # 'location', 'activity', 'theme', 'time'
      t.string :entity_value, null: false
      t.float :confidence
      t.timestamps
      
      t.index [:entity_type, :entity_value]
      t.index :entity_value
    end
    
    # Search query analytics
    create_table :search_queries do |t|
      t.text :query, null: false
      t.string :search_type # 'vector', 'hybrid', 'entity'
      t.json :results
      t.float :execution_time
      t.string :user_session # for analytics
      t.integer :result_count
      t.timestamps
      
      t.index :search_type
      t.index :created_at
    end
  end
end
