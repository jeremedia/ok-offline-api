module Api
  module V1
    class SearchController < BaseController
      before_action :set_search_service, only: %i[vector hybrid]
      before_action :require_vector_service, only: :vector
      rescue_from Search::EmbeddingService::ProviderError, with: :render_vector_unavailable

      # POST /api/v1/search/vector
      def vector
        result = @search_service.search(
          query: search_params[:query],
          year: search_params[:year] || current_burn_year,
          item_types: search_params[:types],
          limit: search_params[:limit] || 20,
          threshold: search_params[:threshold] || Search::VectorSearchService::DEFAULT_THRESHOLD
        )

        render_search_result(result)
      end

      # POST /api/v1/search/hybrid
      def hybrid
        result = @search_service.hybrid_search(
          query: search_params[:query],
          year: search_params[:year] || current_burn_year,
          item_types: search_params[:types],
          limit: search_params[:limit] || 20
        )

        render_search_result(result)
      end

      # POST /api/v1/search/entities
      def entities
        result = Search::EntitySearchService.new.search(
          entities: search_params[:entities],
          year: search_params[:year] || current_burn_year,
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
            vector: SearchQuery.average_execution_time(search_type: "vector"),
            hybrid: SearchQuery.average_execution_time(search_type: "hybrid"),
            entity: SearchQuery.average_execution_time(search_type: "entity")
          },
          success_rate: SearchQuery.search_success_rate,
          total_searches: SearchQuery.count
        }
      end

      # Reports local index state without constructing an embedding client.
      def status
        year = (params[:year] || current_burn_year).to_i
        scope = SearchableItem.by_year(year).where(item_type: %w[camp art event])
        total = scope.count
        embedded = scope.with_embedding.count
        latest_import = SeasonImportRun.where(year: year).order(created_at: :desc).first

        render json: {
          year: year,
          available: Search::EmbeddingService.available? && total.positive? && total == embedded,
          vector_service_configured: Search::EmbeddingService.available?,
          total_count: total,
          embedded_count: embedded,
          embedding_model: Search::EmbeddingService::EMBEDDING_MODEL,
          import: latest_import && {
            id: latest_import.id,
            status: latest_import.status,
            stage: latest_import.stage,
            processed: latest_import.processed,
            total: latest_import.total,
            progress_percentage: latest_import.progress_percentage,
            heartbeat_at: latest_import.heartbeat_at
          }
        }
      end

      # GET /api/v1/search/entity_counts
      def entity_counts
        year = params[:year] || current_burn_year
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

      def require_vector_service
        return if Search::EmbeddingService.available?
        render_vector_unavailable
      end

      def render_vector_unavailable(_error = nil)
        render json: {
          error: {
            code: "vector_search_unavailable",
            message: "Semantic search is temporarily unavailable; use keyword search."
          }
        }, status: :service_unavailable
      end

      def current_burn_year
        Rails.application.config.x.current_burn_year
      end

      def search_params
        params.permit(:query, :year, :limit, :threshold, search: {}, types: [], entities: [])
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
