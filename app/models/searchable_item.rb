class SearchableItem < ApplicationRecord
  # Associations
  has_many :search_entities, dependent: :destroy
  
  # Validations
  validates :uid, presence: true, uniqueness: true
  validates :item_type, presence: true, inclusion: { 
    in: %w[camp art event experience_story historical_fact infrastructure practical_guide timeline_event essay speech philosophical_text manifesto interview letter note theme_essay policy_essay] 
  }
  validates :year, presence: true
  validates :name, presence: true
  
  # Neighbor gem for vector similarity search
  has_neighbors :embedding
  
  # Scopes
  scope :by_type, ->(type) { where(item_type: type) }
  scope :by_year, ->(year) { where(year: year) }
  scope :with_embedding, -> { where.not(embedding: nil) }
  
  # Instance methods
  def prepare_searchable_text
    parts = [name]
    parts << description if description.present?
    
    # Add type-specific fields from metadata
    if metadata.present?
      case item_type
      when 'camp'
        parts << metadata['hometown'] if metadata['hometown']
        parts << metadata['landmark'] if metadata['landmark']
      when 'art'
        parts << metadata['artist'] if metadata['artist']
        parts << metadata['category'] if metadata['category']
      when 'event'
        parts << metadata['event_type']['label'] if metadata.dig('event_type', 'label')
      end
    end
    
    self.searchable_text = parts.compact.join(' ')
  end
  
  def generate_embedding!(embedding_service = nil)
    embedding_service ||= EmbeddingService.new
    
    prepare_searchable_text if searchable_text.blank?
    
    # Generate embedding from searchable text
    embedding_vector = embedding_service.generate_embedding(searchable_text)
    
    # Update record with embedding
    update!(embedding: embedding_vector) if embedding_vector
  end
  
  # Class methods for search
  def self.vector_search(query_embedding, limit: 20, threshold: 0.7)
    # Use the neighbor gem's nearest_neighbors method
    # The neighbor gem handles the vector conversion and distance calculation
    nearest_neighbors(:embedding, query_embedding, distance: "cosine")
      .limit(limit)
  end
  
  def self.hybrid_search(query, query_embedding, limit: 20)
    # Combine vector similarity with keyword matching
    vector_results = vector_search(query_embedding, limit: limit * 2)
    keyword_results = where("searchable_text ILIKE ?", "%#{query}%").limit(limit)
    
    # Merge and deduplicate results
    combined_ids = (vector_results.pluck(:id) + keyword_results.pluck(:id)).uniq
    where(id: combined_ids).limit(limit)
  end
end