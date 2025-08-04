module Search
  # UnifiedSearchService - Combines vector similarity search with Neo4j knowledge graph
  #
  # This service provides a truly unified search experience by:
  # 1. Using vector embeddings to find semantically similar items
  # 2. Enriching results with Neo4j graph relationships
  # 3. Expanding results through graph traversal
  # 4. Ranking results using both similarity scores and graph connectivity
  #
  class UnifiedSearchService
    def initialize
      @vector_service = VectorSearchService.new
      @graph_service = Neo4jGraphService.new
      @embedding_service = EmbeddingService.new
    end
    
    def search(query:, year: 2025, item_types: nil, limit: 20, expand_graph: true, graph_depth: 1)
      start_time = Time.current
      
      # Step 1: Perform vector search to get initial results
      vector_results = @vector_service.search(
        query: query,
        year: year,
        item_types: item_types,
        limit: limit * 2  # Get more results for graph expansion
      )
      
      return vector_results if vector_results[:error] || !expand_graph
      
      # Step 2: Extract entities from the query for graph search
      query_entities = extract_query_entities(query)
      
      # Transform vector results to unified format
      # Need to load actual items to get database IDs for Neo4j
      uids = vector_results[:results].map { |r| r[:uid] }
      items_by_uid = SearchableItem.where(uid: uids).index_by(&:uid)
      
      transformed_results = vector_results[:results].map do |result|
        item = items_by_uid[result[:uid]]
        next unless item
        
        {
          item: {
            id: item.id,  # Use actual database ID for Neo4j
            uid: item.uid,
            name: item.name,
            description: item.description,
            year: item.year,
            item_type: item.item_type,
            location_string: item.location_string
          },
          similarity_score: result[:similarity_score] || 0.0,
          entities: result[:entities] || []
        }
      end.compact
      
      # Step 3: Enrich results with graph data and expand through relationships
      enriched_results = enrich_with_graph_data(
        transformed_results,
        query_entities,
        graph_depth: graph_depth,
        limit: limit
      )
      
      # Step 4: Combine and rank results
      final_results = combine_and_rank_results(
        enriched_results,
        query_entities,
        limit: limit
      )
      
      execution_time = Time.current - start_time
      
      {
        results: final_results,
        total_count: final_results.size,
        execution_time: execution_time.round(3),
        search_type: 'unified',
        query_entities: query_entities,
        graph_expansion_count: count_graph_expansions(enriched_results)
      }
    rescue => e
      Rails.logger.error "Unified search error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # Fallback to vector search if graph service fails
      @vector_service.search(
        query: query,
        year: year,
        item_types: item_types,
        limit: limit
      )
    ensure
      @graph_service&.close
    end
    
    private
    
    def extract_query_entities(query)
      # Extract potential entities from the query using existing entity extraction
      entities = []
      
      # Check for exact matches in our entity database
      SearchEntity.where("entity_value ILIKE ?", "%#{query}%")
                  .distinct
                  .pluck(:entity_type, :entity_value)
                  .each do |type, value|
        entities << { type: type, value: value } if value.present?
      end
      
      # Also check for partial matches on important entity types
      %w[location activity theme].each do |entity_type|
        SearchEntity.where(entity_type: entity_type)
                    .where("entity_value ILIKE ?", "%#{query.split.first}%")
                    .limit(5)
                    .pluck(:entity_value)
                    .each do |value|
          entities << { type: entity_type, value: value } if value.present?
        end
      end
      
      entities.uniq
    end
    
    def enrich_with_graph_data(vector_results, query_entities, graph_depth:, limit:)
      return vector_results if vector_results.empty?
      
      enriched = []
      
      @graph_service.with_session do |session|
        vector_results.each do |result|
          item = result[:item]
          
          # Get graph data for this item
          graph_data = fetch_item_graph_data(session, item, graph_depth)
          
          # Calculate graph relevance score
          graph_score = calculate_graph_relevance(graph_data, query_entities)
          
          enriched << result.merge(
            graph_data: graph_data,
            graph_score: graph_score,
            combined_score: (result[:similarity_score] * 0.7 + graph_score * 0.3).round(3)
          )
        end
        
        # Expand search through graph if we have query entities
        if query_entities.any? && enriched.size < limit
          graph_expansions = expand_through_graph(session, query_entities, enriched, limit)
          enriched.concat(graph_expansions)
        end
      end
      
      enriched
    end
    
    def fetch_item_graph_data(session, item, depth)
      # Get all entities for this item
      # item is now a hash, so we need to fetch entities from DB
      searchable_item = SearchableItem.find(item[:id])
      entities = searchable_item.search_entities.pluck(:entity_type, :entity_value)
      
      # Get graph connections
      connections = []
      related_items = []
      
      # Query Neo4j for connections
      entities.each do |entity_type, entity_value|
        # Skip pool entities for now (focus on basic entities)
        next if entity_type.start_with?('pool_')
        
        # Find items connected through this entity
        # Build the Neo4j UID for this item
        neo4j_uid = "#{searchable_item.item_type}-#{searchable_item.year}-#{searchable_item.id}"
        
        cypher = <<~CYPHER
          MATCH (i:BM_Item {uid: $item_uid})-[:BM_HAS_ENTITY]->(e:BM_Entity {name: $entity_name})
          OPTIONAL MATCH (e)<-[:BM_HAS_ENTITY]-(other:BM_Item)
          WHERE other.uid <> $item_uid
          WITH e, COLLECT(DISTINCT other.uid) as connected_items
          OPTIONAL MATCH (e)-[:BM_APPEARS_WITH]-(related:BM_Entity)
          WHERE related.name <> $entity_name
          RETURN e.name as entity,
                 e.pool as pool,
                 connected_items,
                 COLLECT(DISTINCT {
                   name: related.name,
                   pool: related.pool,
                   strength: 1
                 }) as related_entities
          LIMIT 1
        CYPHER
        
        result = session.run(cypher, 
          item_uid: neo4j_uid, 
          entity_name: entity_value
        ).to_a.first
        
        if result
          connections << {
            entity: entity_value,
            entity_type: entity_type,
            pool: result[:pool],
            connected_items: result[:connected_items] || [],
            related_entities: result[:related_entities] || []
          }
          
          related_items.concat(result[:connected_items] || [])
        end
      end
      
      {
        entity_count: entities.size,
        connections: connections,
        related_item_ids: related_items.uniq,
        graph_density: calculate_graph_density(connections)
      }
    end
    
    def calculate_graph_relevance(graph_data, query_entities)
      return 0.0 if query_entities.empty? || graph_data[:connections].empty?
      
      relevance_score = 0.0
      
      # Check for direct entity matches
      query_entity_values = query_entities.map { |e| e[:value]&.downcase }.compact
      
      graph_data[:connections].each do |connection|
        # Direct match bonus
        if connection[:entity] && query_entity_values.include?(connection[:entity].downcase)
          relevance_score += 0.5
        end
        
        # Related entity bonus
        connection[:related_entities].each do |related|
          if related[:name] && query_entity_values.include?(related[:name].downcase)
            relevance_score += 0.3
          end
        end
        
        # Connection density bonus
        relevance_score += connection[:connected_items].size * 0.01
      end
      
      # Normalize to 0-1 range
      [relevance_score / [query_entities.size, 1].max, 1.0].min
    end
    
    def expand_through_graph(session, query_entities, existing_results, limit)
      existing_ids = existing_results.map { |r| r[:item][:id] }
      expansions = []
      
      query_entities.each do |entity|
        # Find items strongly connected to this entity
        # Convert existing IDs to Neo4j UIDs
        existing_uids = existing_results.map do |r| 
          item = r[:item]
          "#{item[:item_type]}-#{item[:year]}-#{item[:id]}"
        end
        
        cypher = <<~CYPHER
          MATCH (e:BM_Entity {name: $entity_name})<-[:BM_HAS_ENTITY]-(i:BM_Item)
          WHERE NOT i.uid IN $existing_uids
          WITH i, e
          OPTIONAL MATCH (i)-[:BM_HAS_ENTITY]->(other:BM_Entity)
          WITH i, COUNT(DISTINCT other) as entity_count, 
               COLLECT(DISTINCT other.name) as other_entities
          RETURN i.uid as uid, i.name as name, i.type as item_type, i.year as year, entity_count, other_entities
          ORDER BY entity_count DESC
          LIMIT $limit
        CYPHER
        
        results = session.run(cypher,
          entity_name: entity[:value],
          existing_uids: existing_uids,
          limit: limit - existing_results.size
        ).to_a
        
        results.each do |result|
          # Extract database ID from Neo4j UID (format: type-year-id)
          uid_parts = result[:uid].split('-')
          db_id = uid_parts.last.to_i
          
          item = SearchableItem.find_by(id: db_id)
          next unless item
          
          # Create a pseudo-vector result for graph expansion
          expansions << {
            item: {
              id: item.id,
              name: item.name,
              description: item.description,
              year: item.year,
              item_type: item.item_type,
              location_string: item.location_string
            },
            similarity_score: 0.0,  # No vector similarity
            graph_score: 0.8,  # High graph relevance
            combined_score: 0.8,
            graph_expansion: true,
            expansion_reason: "Connected through: #{entity[:value]}",
            entity_count: result[:entity_count]
          }
        end
      end
      
      expansions.uniq { |e| e[:item][:id] }
    end
    
    def combine_and_rank_results(enriched_results, query_entities, limit:)
      # Sort by combined score (vector similarity + graph relevance)
      sorted = enriched_results.sort_by { |r| -r[:combined_score] }
      
      # Take top results
      final_results = sorted.first(limit)
      
      # Format for API response
      final_results.map do |result|
        item = result[:item]
        
        {
          id: item[:id],
          name: item[:name],
          description: item[:description],
          year: item[:year],
          item_type: item[:item_type],
          location_string: item[:location_string],
          similarity_score: result[:similarity_score],
          graph_score: result[:graph_score],
          combined_score: result[:combined_score],
          graph_expansion: result[:graph_expansion] || false,
          expansion_reason: result[:expansion_reason],
          entity_connections: format_entity_connections(result[:graph_data])
        }
      end
    end
    
    def format_entity_connections(graph_data)
      return nil unless graph_data
      
      {
        total_entities: graph_data[:entity_count],
        connections: graph_data[:connections].map do |conn|
          {
            entity: conn[:entity],
            type: conn[:entity_type],
            connected_items: conn[:connected_items].size,
            related_entities: conn[:related_entities].size
          }
        end,
        graph_density: graph_data[:graph_density]
      }
    end
    
    def calculate_graph_density(connections)
      return 0.0 if connections.empty?
      
      total_connections = connections.sum { |c| c[:connected_items].size + c[:related_entities].size }
      (total_connections.to_f / connections.size).round(2)
    end
    
    def count_graph_expansions(results)
      results.count { |r| r[:graph_expansion] == true }
    end
  end
end