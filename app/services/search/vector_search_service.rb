module Search
  class VectorSearchService
    DEFAULT_THRESHOLD = 0.4

    def initialize(embedding_service: nil)
      @embedding_service = embedding_service || (EmbeddingService.new if EmbeddingService.available?)
    end

    def search(query:, year: Rails.application.config.x.current_burn_year, item_types: nil, limit: 20, threshold: DEFAULT_THRESHOLD)
      # Generate embedding for query
      query_embedding = @embedding_service&.generate_embedding(query)
      return empty_result if query_embedding.nil?

      # Start timing
      start_time = Time.current

      # Build base query
      scope = SearchableItem.with_embedding
      scope = scope.by_year(year) if year.present?
      scope = scope.where(item_type: item_types) if item_types.present?

      # Perform vector similarity search
      candidates = with_vector_search_config do
        scope.vector_search(query_embedding, limit: limit * 5).to_a
      end

      # Calculate execution time
      execution_time = Time.current - start_time

      result = format_results(
        candidates, query_embedding, execution_time,
        search_type: "vector", threshold: threshold, limit: limit
      )
      log_search_query(query, "vector", result[:results], execution_time)
      result
    end

    def hybrid_search(query:, year: Rails.application.config.x.current_burn_year, item_types: nil, limit: 20)
      # Generate embedding for query
      query_embedding = @embedding_service&.generate_embedding(query)

      start_time = Time.current

      # Build base query
      scope = SearchableItem.all
      scope = scope.by_year(year) if year.present?
      scope = scope.where(item_type: item_types) if item_types.present?

      # Perform hybrid search (vector + keyword)
      results = if query_embedding
        with_vector_search_config { scope.hybrid_search(query, query_embedding, limit: limit).to_a }
      else
        # Fallback to keyword search if embedding fails
        scope.where("searchable_text ILIKE ?", "%#{query}%").limit(limit).to_a
      end

      execution_time = Time.current - start_time

      search_type = query_embedding ? "hybrid" : "keyword"
      result = format_results(results, query_embedding, execution_time, search_type: search_type, limit: limit)
      log_search_query(query, "hybrid", result[:results], execution_time)
      result
    end

    private

    def empty_result
      {
        results: [],
        total_count: 0,
        execution_time: 0,
        search_type: "vector",
        error: "Failed to generate query embedding"
      }
    end

    def format_results(results, query_embedding, execution_time, search_type:, threshold: nil, limit: nil)
      formatted_results = results.map do |item|
        result = {
          uid: item.uid,
          name: item.name,
          type: item.item_type,
          year: item.year,
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
      formatted_results.select! { |result| result[:similarity_score] >= threshold.to_f } if threshold
      formatted_results = formatted_results.first(limit) if limit

      {
        results: formatted_results,
        total_count: formatted_results.count,
        execution_time: (execution_time * 1000).round(2), # in milliseconds
        search_type: search_type
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

    # pgvector's filtered HNSW scans otherwise stop after inspecting the global
    # candidate set, which can return fewer than the requested number for a
    # single year. Keep these settings transaction-local to the checked-out
    # connection and load the relation before they revert.
    def with_vector_search_config
      SearchableItem.connection.transaction(requires_new: true) do
        SearchableItem.connection.execute("SET LOCAL hnsw.ef_search = 100")
        SearchableItem.connection.execute("SET LOCAL hnsw.iterative_scan = strict_order")
        SearchableItem.connection.execute("SET LOCAL hnsw.max_scan_tuples = 50000")
        yield
      end
    end

    def log_search_query(query, search_type, results, execution_time)
      SearchQuery.create!(
        query: query.truncate(1000),
        search_type: search_type,
        result_count: results.count,
        execution_time: execution_time,
        user_session: nil
      )
    rescue => e
      Rails.logger.error("Failed to log search query: #{e.message}")
    end
  end
end
