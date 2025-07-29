module Api
  module V1
    class EmbeddingsController < BaseController
      # POST /api/v1/embeddings/generate
      def generate
        text = params[:text]
        
        if text.blank?
          render json: { error: 'Text is required' }, status: :bad_request
          return
        end
        
        embedding_service = Search::EmbeddingService.new
        embedding = embedding_service.generate_embedding(text)
        
        if embedding
          render json: {
            text: text.truncate(100),
            embedding: embedding,
            model: 'text-embedding-ada-002',
            dimensions: embedding.size
          }
        else
          render json: { error: 'Failed to generate embedding' }, status: :unprocessable_entity
        end
      end
      
      # POST /api/v1/embeddings/batch_import
      def batch_import
        year = params[:year] || 2025
        types = params[:types] || ['camp', 'art', 'event']
        
        # Run import job asynchronously
        ImportDataJob.perform_later(year, types)
        
        render json: {
          message: 'Import job queued',
          year: year,
          types: types,
          job_id: SecureRandom.uuid # In a real app, return actual job ID
        }
      end
      
      # GET /api/v1/embeddings/status
      def status
        total_items = SearchableItem.count
        items_with_embeddings = SearchableItem.with_embedding.count
        
        by_type = SearchableItem.group(:item_type).count
        embeddings_by_type = SearchableItem.with_embedding.group(:item_type).count
        
        render json: {
          total_items: total_items,
          items_with_embeddings: items_with_embeddings,
          percentage_complete: total_items > 0 ? (items_with_embeddings.to_f / total_items * 100).round(2) : 0,
          by_type: by_type.map do |type, count|
            {
              type: type,
              total: count,
              with_embeddings: embeddings_by_type[type] || 0,
              percentage: count > 0 ? ((embeddings_by_type[type] || 0).to_f / count * 100).round(2) : 0
            }
          end
        }
      end
    end
  end
end