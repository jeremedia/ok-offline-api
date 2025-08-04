# frozen_string_literal: true

module Api
  module V1
    class GraphSearchController < ApplicationController
      before_action :initialize_graph_service
      after_action :close_graph_service
      
      # GET /api/v1/graph/entity/:name
      def entity
        entity_name = params[:name]
        pool = params[:pool]
        
        results = {
          entity: entity_name,
          pool: pool,
          related_items: @service.find_related_items(entity_name, pool: pool, limit: 20),
          connections: @service.find_entity_connections(entity_name, max_depth: 2)
        }
        
        render json: results
      rescue => e
        render json: { error: e.message }, status: :internal_server_error
      end
      
      # GET /api/v1/graph/bridge
      def bridge
        pool1 = params[:pool1] || 'manifest'
        pool2 = params[:pool2] || 'experience'
        
        results = {
          pool1: pool1,
          pool2: pool2,
          bridges: @service.find_pool_bridges(pool1, pool2)
        }
        
        render json: results
      rescue => e
        render json: { error: e.message }, status: :internal_server_error
      end
      
      # POST /api/v1/graph/query
      def query
        cypher = params[:query]
        
        unless cypher.present?
          render json: { error: "Query parameter required" }, status: :bad_request
          return
        end
        
        # Only allow read queries
        if cypher.downcase.include?('create') || cypher.downcase.include?('delete') || 
           cypher.downcase.include?('merge') || cypher.downcase.include?('set')
          render json: { error: "Only read queries allowed" }, status: :forbidden
          return
        end
        
        @service.with_session do |session|
          results = session.run(cypher).to_a
          render json: { results: results }
        end
      rescue => e
        render json: { error: e.message }, status: :internal_server_error
      end
      
      # GET /api/v1/graph/stats
      def stats
        @service.with_session do |session|
          item_count = session.run("MATCH (i:BM_Item) RETURN COUNT(i) as count").single[:count]
          entity_count = session.run("MATCH (e:BM_Entity) RETURN COUNT(e) as count").single[:count]
          has_entity_count = session.run("MATCH ()-[r:BM_HAS_ENTITY]->() RETURN COUNT(r) as count").single[:count]
          appears_with_count = session.run("MATCH ()-[r:BM_APPEARS_WITH]->() RETURN COUNT(r) as count").single[:count]
          
          pool_stats = session.run(<<~CYPHER
            MATCH (e:BM_Entity)
            RETURN e.pool as pool, COUNT(e) as count
            ORDER BY count DESC
          CYPHER
          ).to_a
          
          render json: {
            nodes: {
              items: item_count,
              entities: entity_count,
              total: item_count + entity_count
            },
            relationships: {
              has_entity: has_entity_count,
              appears_with: appears_with_count,
              total: has_entity_count + appears_with_count
            },
            pools: pool_stats
          }
        end
      rescue => e
        render json: { error: e.message }, status: :internal_server_error
      end
      
      # GET /api/v1/graph/export/pool/:pool_name
      def export_pool
        pool = params[:pool_name]
        limit = (params[:limit] || 1000).to_i
        offset = (params[:offset] || 0).to_i
        
        @service.with_session do |session|
          # Get total count
          total_result = session.run("MATCH (e:BM_Entity {pool: $pool}) RETURN COUNT(e) as count", pool: pool)
          total_count = total_result.single[:count]
          
          # Get entities for pool with pagination
          entity_results = session.run(<<~CYPHER, pool: pool, offset: offset, limit: limit).to_a
            MATCH (e:BM_Entity {pool: $pool})
            WITH e ORDER BY e.occurrence_count DESC
            SKIP $offset LIMIT $limit
            RETURN e.name as id, e.name as label, 
                   COALESCE(e.occurrence_count, 1) as size, $pool as pool
          CYPHER
          
          entities = entity_results.map do |result|
            {
              id: result[:id],
              label: result[:label],
              size: result[:size],
              pool: result[:pool]
            }
          end
          
          # Get relationships between entities in this pool
          edge_results = session.run(<<~CYPHER, pool: pool, offset: offset, limit: limit).to_a
            MATCH (e1:BM_Entity {pool: $pool})-[r:BM_APPEARS_WITH]-(e2:BM_Entity {pool: $pool})
            WHERE e1.name < e2.name
            WITH e1, e2, r ORDER BY r.count DESC
            SKIP $offset LIMIT $limit
            RETURN e1.name as source, e2.name as target, 
                   r.count as weight
          CYPHER
          
          edges = edge_results.map do |result|
            {
              source: result[:source],
              target: result[:target],
              weight: result[:weight]
            }
          end
          
          render json: {
            nodes: entities,
            edges: edges,
            pool: pool,
            total_entities: total_count,
            has_more: offset + limit < total_count
          }
        end
      rescue => e
        render json: { error: e.message }, status: :internal_server_error
      end
      
      # GET /api/v1/graph/export/neighborhood/:entity_id
      def export_neighborhood
        entity_name = params[:entity_id]
        depth = (params[:depth] || 2).to_i
        
        Rails.logger.info "export_neighborhood called with entity: #{entity_name}, depth: #{depth}"
        
        center_node = nil
        neighbors = []
        edges = []
        
        @service.with_session do |session|
          # Get the center entity
          Rails.logger.info "Searching for entity: #{entity_name}"
          center = session.run(<<~CYPHER, name: entity_name).to_a.first
            MATCH (e:BM_Entity {name: $name})
            RETURN e.name as id, e.name as label, 
                   e.pool as pool, COALESCE(e.occurrence_count, 1) as size
            LIMIT 1
          CYPHER
          
          Rails.logger.info "Center result: #{center.inspect}"
          
          # Only proceed if center exists
          unless center.nil?
            # Format center properly
            center_node = {
              id: center[:id],
              label: center[:label],
              pool: center[:pool],
              size: center[:size]
            }
            
            # Get connected entities within depth
            neighbor_results = session.run(<<~CYPHER, name: entity_name).to_a
              MATCH path = (e1:BM_Entity {name: $name})-[:BM_APPEARS_WITH*1..#{depth}]-(e2:BM_Entity)
              WHERE e1 <> e2
              WITH DISTINCT e2, MIN(LENGTH(path)) as distance
              RETURN e2.name as id, e2.name as label, 
                     e2.pool as pool, COALESCE(e2.occurrence_count, 1) as size,
                     distance
              ORDER BY distance, size DESC
              LIMIT 100
            CYPHER
            
            Rails.logger.info "Found #{neighbor_results.count} neighbors"
            
            neighbors = neighbor_results.map do |result|
              {
                id: result[:id],
                label: result[:label],
                pool: result[:pool],
                size: result[:size],
                distance: result[:distance]
              }
            end
            
            # Get edges
            edge_results = session.run(<<~CYPHER, node_names: [center_node[:id]] + neighbors.map { |n| n[:id] }).to_a
              MATCH (e1:BM_Entity)-[r:BM_APPEARS_WITH]-(e2:BM_Entity)
              WHERE e1.name IN $node_names AND e2.name IN $node_names
                    AND e1.name < e2.name
              RETURN e1.name as source, e2.name as target, r.count as weight
            CYPHER
            
            Rails.logger.info "Found #{edge_results.count} edges"
            
            edges = edge_results.map do |result|
              {
                source: result[:source],
                target: result[:target],
                weight: result[:weight]
              }
            end
          end
        end
        
        # Handle response after the block
        if center_node.nil?
          Rails.logger.info "Entity not found, returning 404"
          render json: { error: "Entity not found" }, status: :not_found
        else
          Rails.logger.info "Returning graph data with #{neighbors.count} neighbors and #{edges.count} edges"
          render json: {
            center: center_node,
            nodes: [center_node] + neighbors,
            edges: edges
          }
        end
      rescue => e
        Rails.logger.error "Error in export_neighborhood: #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        render json: { error: e.message }, status: :internal_server_error
      end
      
      # GET /api/v1/graph/clusters
      def clusters
        pools = params[:pools] || ['manifest', 'experience', 'relational', 'practical', 'idea', 'evolutionary', 'emanation']
        
        @service.with_session do |session|
          # Get pool statistics
          pool_results = session.run(<<~CYPHER, pools: pools).to_a
            MATCH (e:BM_Entity)
            WHERE e.pool IN $pools
            WITH e.pool as pool, COUNT(e) as count
            RETURN pool as id, pool as label, count as size, pool
            ORDER BY size DESC
          CYPHER
          
          pool_nodes = pool_results.map do |result|
            {
              id: result[:id],
              label: result[:label].capitalize,
              size: result[:size],
              pool: result[:pool]
            }
          end
          
          # Get cross-pool relationships
          edge_results = session.run(<<~CYPHER, pools: pools).to_a
            MATCH (e1:BM_Entity)-[:BM_APPEARS_WITH]-(e2:BM_Entity)
            WHERE e1.pool IN $pools AND e2.pool IN $pools 
                  AND e1.pool < e2.pool
            WITH e1.pool as source, e2.pool as target, COUNT(*) as weight
            RETURN source, target, weight
            ORDER BY weight DESC
          CYPHER
          
          pool_edges = edge_results.map do |result|
            {
              source: result[:source],
              target: result[:target],
              weight: result[:weight]
            }
          end
          
          render json: {
            nodes: pool_nodes,
            edges: pool_edges,
            type: 'clusters'
          }
        end
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