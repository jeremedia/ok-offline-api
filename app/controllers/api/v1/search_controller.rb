module Api
  module V1
    class SearchController < BaseController
      before_action :set_search_service
      
      # POST /api/v1/search/vector
      def vector
        result = @search_service.search(
          query: search_params[:query],
          year: search_params[:year] || 2025,
          item_types: search_params[:types],
          limit: search_params[:limit] || 20,
          threshold: search_params[:threshold] || 0.7
        )
        
        render_search_result(result)
      end
      
      # POST /api/v1/search/hybrid
      def hybrid
        result = @search_service.hybrid_search(
          query: search_params[:query],
          year: search_params[:year] || 2025,
          item_types: search_params[:types],
          limit: search_params[:limit] || 20
        )
        
        render_search_result(result)
      end
      
      # POST /api/v1/search/entities
      def entities
        result = @search_service.entity_search(
          entities: search_params[:entities],
          year: search_params[:year] || 2025,
          item_types: search_params[:types],
          limit: search_params[:limit] || 20
        )
        
        render_search_result(result)
      end
      
      # POST /api/v1/search/suggest
      def suggest
        # Simple entity-based suggestions for now
        suggestions = SearchEntity
          .where("entity_value ILIKE ?", "#{search_params[:query]}%")
          .distinct
          .limit(10)
          .pluck(:entity_value)
        
        render json: {
          query: search_params[:query],
          suggestions: suggestions
        }
      end
      
      # GET /api/v1/search/analytics
      def analytics
        # Basic analytics for now - could be expanded
        render json: {
          popular_queries: SearchQuery.popular_queries,
          average_execution_time: {
            vector: SearchQuery.average_execution_time(search_type: 'vector'),
            hybrid: SearchQuery.average_execution_time(search_type: 'hybrid'),
            entity: SearchQuery.average_execution_time(search_type: 'entity')
          },
          success_rate: SearchQuery.search_success_rate,
          total_searches: SearchQuery.count
        }
      end
      
      # GET /api/v1/search/entity_counts
      def entity_counts
        year = params[:year] || 2025
        entity_type = params[:entity_type]
        
        if entity_type.present?
          # Get popular entities for a specific type
          popular = SearchEntity.popular_entities(
            entity_type: entity_type, 
            year: year, 
            limit: params[:limit] || 20
          )
          
          render json: {
            year: year,
            entity_type: entity_type,
            popular_entities: popular,
            total_count: popular.values.sum
          }
        else
          # Get entity type counts
          type_counts = SearchEntity.entity_type_counts(year: year)
          
          render json: {
            year: year,
            entity_type_counts: type_counts,
            total_entities: type_counts.values.sum
          }
        end
      end
      
      private
      
      def set_search_service
        @search_service = Search::VectorSearchService.new
      end
      
      def search_params
        params.permit(:query, :year, :limit, :threshold, search:{}, types: [], entities: [])
      end
      
      def render_search_result(result)
        if result[:error]
          render json: {
            error: result[:error],
            results: [],
            meta: {
              execution_time: result[:execution_time],
              search_type: result[:search_type]
            }
          }, status: :unprocessable_entity
        else
          response = {
            results: result[:results],
            meta: {
              total_count: result[:total_count],
              execution_time: result[:execution_time],
              search_type: result[:search_type]
            }
          }
          
          # Include entity_tag_summary if present
          response[:entity_tag_summary] = result[:entity_tag_summary] if result[:entity_tag_summary]
          
          render json: response
        end
      end
    end
  end
end