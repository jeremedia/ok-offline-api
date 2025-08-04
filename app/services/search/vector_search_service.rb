module Search
  class VectorSearchService
    def initialize
      @embedding_service = EmbeddingService.new
    end
    
    def search(query:, year: 2025, item_types: nil, limit: 20, threshold: 0.7)
      # Generate embedding for query
      query_embedding = @embedding_service.generate_embedding(query)
      return empty_result if query_embedding.nil?
      
      # Start timing
      start_time = Time.current
      
      # Build base query
      scope = SearchableItem.with_embedding
      scope = scope.by_year(year) if year.present?
      scope = scope.where(item_type: item_types) if item_types.present?
      
      # Perform vector similarity search
      results = scope.vector_search(query_embedding, limit: limit, threshold: threshold)
      
      # Calculate execution time
      execution_time = Time.current - start_time
      
      # Log search query for analytics
      log_search_query(query, 'vector', results.to_a, execution_time)
      
      # Format results
      format_results(results, query_embedding, execution_time)
    end
    
    def hybrid_search(query:, year: 2025, item_types: nil, limit: 20)
      # Generate embedding for query
      query_embedding = @embedding_service.generate_embedding(query)
      
      start_time = Time.current
      
      # Build base query
      scope = SearchableItem.all
      scope = scope.by_year(year) if year.present?
      scope = scope.where(item_type: item_types) if item_types.present?
      
      # Perform hybrid search (vector + keyword)
      results = if query_embedding
        scope.hybrid_search(query, query_embedding, limit: limit)
      else
        # Fallback to keyword search if embedding fails
        scope.where("searchable_text ILIKE ?", "%#{query}%").limit(limit)
      end
      
      execution_time = Time.current - start_time
      
      # Log search query
      log_search_query(query, 'hybrid', results.to_a, execution_time)
      
      # Format results
      format_results(results, query_embedding, execution_time)
    end
    
    def entity_search(entities:, year: 2025, item_types: nil, limit: 20)
      start_time = Time.current
      
      # Search by entities
      results = SearchEntity
        .joins(:searchable_item)
        .where(entity_value: entities)
        .where(searchable_items: { year: year })
      
      results = results.where(searchable_items: { item_type: item_types }) if item_types.present?
      
      # Get unique searchable item IDs ordered by entity match count
      item_ids = results
        .group('searchable_items.id')
        .order('COUNT(search_entities.id) DESC')
        .limit(limit)
        .pluck('searchable_items.id')
      
      # Load the searchable items
      results = SearchableItem.where(id: item_ids).includes(:search_entities)
      
      execution_time = Time.current - start_time
      
      # Log search query
      log_search_query(entities.join(', '), 'entity', results.to_a, execution_time)
      
      # Format results
      format_results(results, nil, execution_time)
    end
    
    private
    
    def empty_result
      {
        results: [],
        total_count: 0,
        execution_time: 0,
        search_type: 'vector',
        error: 'Failed to generate query embedding'
      }
    end
    
    def format_results(results, query_embedding, execution_time)
      formatted_results = results.map do |item|
        result = {
          uid: item.uid,
          name: item.name,
          type: item.item_type,
          description: item.description,
          metadata: item.metadata
        }
        
        # Add similarity score if we have embeddings
        if query_embedding && item.embedding
          result[:similarity_score] = cosine_similarity(query_embedding, item.embedding)
        end
        
        # Include related entities
        if item.search_entities.any?
          result[:entities] = item.search_entities.pluck(:entity_type, :entity_value)
        end
        
        result
      end
      
      {
        results: formatted_results,
        total_count: formatted_results.count,
        execution_time: (execution_time * 1000).round(2), # in milliseconds
        search_type: query_embedding ? 'vector' : 'keyword'
      }
    end
    
    def cosine_similarity(vec1, vec2)
      # Calculate cosine similarity between two vectors
      dot_product = vec1.zip(vec2).sum { |a, b| a * b }
      magnitude1 = Math.sqrt(vec1.sum { |a| a**2 })
      magnitude2 = Math.sqrt(vec2.sum { |a| a**2 })
      
      return 0 if magnitude1 == 0 || magnitude2 == 0
      
      (dot_product / (magnitude1 * magnitude2)).round(4)
    end
    
    def log_search_query(query, search_type, results, execution_time)
      SearchQuery.create!(
        query: query.truncate(1000),
        search_type: search_type,
        result_count: results.count,
        execution_time: execution_time,
        user_session: RequestStore.store[:session_id]
      )
    rescue => e
      Rails.logger.error("Failed to log search query: #{e.message}")
    end
  end
end