# frozen_string_literal: true

# Neighbor gem configuration for pgvector
# Optimized for 54,555+ searchable items with 1536-dimensional embeddings

# Configure neighbor for production use with large datasets
Rails.application.config.after_initialize do
  # Set pgvector search parameters for better performance
  # ef_search controls the quality/speed tradeoff for HNSW indexes
  # Higher values = better recall but slower searches
  # Default is 40, we increase to 100 for better quality on our dataset
  if defined?(ActiveRecord::Base.connection) && ActiveRecord::Base.connected?
    begin
      # Set search parameters for the session
      ActiveRecord::Base.connection.execute("SET hnsw.ef_search = 100")
      Rails.logger.info "Neighbor: Set hnsw.ef_search to 100 for improved search quality"
    rescue => e
      Rails.logger.warn "Neighbor: Could not set hnsw.ef_search: #{e.message}"
    end
  end
end

# Monkey patch to add search configuration methods
module NeighborSearchExtensions
  extend ActiveSupport::Concern

  class_methods do
    # Perform vector search with custom ef_search parameter
    def vector_search_with_config(query_embedding, limit: 20, ef_search: 100)
      connection.execute("SET LOCAL hnsw.ef_search = #{ef_search}")
      nearest_neighbors(:embedding, query_embedding, distance: "cosine").limit(limit)
    end

    # Perform high-quality search (slower but more accurate)
    def high_quality_vector_search(query_embedding, limit: 20)
      vector_search_with_config(query_embedding, limit: limit, ef_search: 200)
    end

    # Perform fast search (less accurate but faster)
    def fast_vector_search(query_embedding, limit: 20)
      vector_search_with_config(query_embedding, limit: limit, ef_search: 40)
    end
  end
end

# Include the extensions in SearchableItem if it exists
Rails.application.config.after_initialize do
  if defined?(SearchableItem)
    SearchableItem.include(NeighborSearchExtensions)
  end
end