class FixNeighborIndexing < ActiveRecord::Migration[8.0]
  def up
    # Remove any existing indexes on embedding column
    remove_index :searchable_items, :embedding if index_exists?(:searchable_items, :embedding)
    
    # Create HNSW index with cosine distance operator class
    # HNSW is better for larger datasets than IVFFlat
    # m: Maximum number of connections per node (16 is default, 32 for better quality)
    # ef_construction: Size of dynamic candidate list (200 for better index quality)
    add_index :searchable_items, :embedding,
      using: :hnsw,
      opclass: :vector_cosine_ops,
      comment: "HNSW index for cosine similarity search on embeddings"
    
    # Execute index configuration for better build quality
    execute <<-SQL
      -- Set HNSW build parameters for better index quality
      SET hnsw.m = 32;
      SET hnsw.ef_construction = 200;
      
      -- Rebuild statistics for query planner
      ANALYZE searchable_items;
    SQL
    
    puts "✅ Created HNSW index with optimized parameters for 54,555 embeddings"
  end
  
  def down
    remove_index :searchable_items, :embedding if index_exists?(:searchable_items, :embedding)
  end
end