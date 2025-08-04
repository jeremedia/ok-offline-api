# frozen_string_literal: true

module Api
  module V1
    class GraphController < ApplicationController
      before_action :initialize_graph_service
      after_action :close_graph_service
      
      # GET /api/v1/graph/bridge_entities
      def bridge_entities
        min_pools = (params[:min_pools] || 2).to_i
        limit = (params[:limit] || 50).to_i
        
        bridge_data = []
        
        @service.with_session do |session|
          # Find entities that span multiple pools with their frequencies and relationships
          query = <<~CYPHER
            MATCH (e:BM_Entity)
            WITH e.name as entity_name, COLLECT(DISTINCT e.pool) as pools, 
                 SUM(e.occurrence_count) as total_frequency,
                 COLLECT(DISTINCT {pool: e.pool, count: e.occurrence_count}) as pool_details
            WHERE SIZE(pools) >= $min_pools
            
            // Get cross-pool centrality for each entity
            OPTIONAL MATCH (e1:BM_Entity {name: entity_name})-[r:BM_APPEARS_WITH]-(e2:BM_Entity)
            WHERE e1.pool <> e2.pool
            WITH entity_name, pools, total_frequency, pool_details,
                 COUNT(DISTINCT r) as cross_pool_relationships
            
            // Calculate bridge power: Pool_Count × sqrt(Total_Frequency) × Cross_Pool_Centrality
            WITH entity_name, pools, total_frequency, pool_details, cross_pool_relationships,
                 SIZE(pools) as pool_count,
                 (SIZE(pools) * sqrt(toFloat(total_frequency)) * (cross_pool_relationships + 1)) as bridge_power
            
            RETURN entity_name, pools, pool_count, total_frequency, 
                   cross_pool_relationships as cross_pool_centrality, bridge_power, pool_details
            ORDER BY bridge_power DESC
            LIMIT $limit
          CYPHER
          
          results = session.run(query, min_pools: min_pools, limit: limit).to_a
          
          bridge_data = results.map do |result|
            # Build pool_frequencies hash from pool_details
            pool_frequencies = {}
            result[:pool_details].each do |detail|
              pool_frequencies[detail[:pool]] = detail[:count]
            end
            
            {
              name: result[:entity_name],
              pools: result[:pools],
              pool_count: result[:pool_count],
              total_frequency: result[:total_frequency],
              cross_pool_centrality: result[:cross_pool_centrality],
              bridge_power: result[:bridge_power].round(1),
              pool_frequencies: pool_frequencies
            }
          end
        end
        
        render json: {
          bridge_entities: bridge_data,
          total_bridges: bridge_data.size,
          parameters: {
            min_pools: min_pools,
            limit: limit
          }
        }
      rescue => e
        render json: { error: e.message }, status: :internal_server_error
      end
      
      private
      
      def initialize_graph_service
        @service = Neo4jGraphService.new
      rescue => e
        render json: { error: "Neo4j connection failed: #{e.message}" }, status: :service_unavailable
      end
      
      def close_graph_service
        @service&.close
      end
    end
  end
end