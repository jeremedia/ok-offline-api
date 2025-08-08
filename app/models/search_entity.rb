class SearchEntity < ApplicationRecord
  # Associations
  belongs_to :searchable_item
  
  # Validations
  validates :entity_type, presence: true, inclusion: { 
    in: %w[location activity theme time person item_type 
           contact organizational service schedule requirement
           pool_idea pool_manifest pool_experience pool_relational 
           pool_evolutionary pool_practical pool_emanation] 
  }
  validates :entity_value, presence: true
  validates :confidence, numericality: { 
    greater_than_or_equal_to: 0, 
    less_than_or_equal_to: 1 
  }, allow_nil: true
  
  # Scopes
  scope :by_type, ->(type) { where(entity_type: type) }
  scope :high_confidence, -> { where("confidence > ?", 0.8) }
  scope :locations, -> { by_type('location') }
  scope :activities, -> { by_type('activity') }
  scope :themes, -> { by_type('theme') }
  scope :item_types, -> { by_type('item_type') }

  # Class methods for entity-based search
  def self.search_by_entities(entity_values)
    joins(:searchable_item)
      .where(entity_value: entity_values)
      .group('searchable_items.id')
      .order('COUNT(search_entities.id) DESC')
      .select('searchable_items.*, COUNT(search_entities.id) as entity_match_count')
  end
  
  # Cache entity type counts for ordering
  def self.entity_type_counts(year: nil)
    cache_key = "entity_type_counts_#{year || 'all'}"
    cache_duration = Rails.env.production? ? 24.hours : 1.hour
    
    Rails.cache.fetch(cache_key, expires_in: cache_duration) do
      scope = year ? joins(:searchable_item).where(searchable_items: { year: year }) : self
      scope.group(:entity_type).count
    end
  end
  
  # Cache entity value counts (how many times each entity value appears)
  def self.entity_value_counts(year: nil, entity_type: nil)
    cache_key = "entity_value_counts_#{year || 'all'}_#{entity_type || 'all'}"
    cache_duration = Rails.env.production? ? 24.hours : 1.hour
    
    Rails.cache.fetch(cache_key, expires_in: cache_duration) do
      scope = year ? joins(:searchable_item).where(searchable_items: { year: year }) : self
      scope = scope.where(entity_type: entity_type) if entity_type.present?
      scope.group(:entity_value).count
    end
  end
  
  # Get entity counts for a specific item's entities (now includes value counts)
  def self.entity_counts_for_item(entities, year: nil)
    type_counts = entity_type_counts(year: year)
    value_counts = entity_value_counts(year: year)
    
    entities.map do |entity|
      entity_hash = entity.is_a?(Array) ? 
        { entity_type: entity[0], entity_value: entity[1] } : 
        { entity_type: entity[:entity_type] || entity["entity_type"], 
          entity_value: entity[:entity_value] || entity["entity_value"] }
      
      entity_hash.merge(
        type_count: type_counts[entity_hash[:entity_type]] || 0,
        value_count: value_counts[entity_hash[:entity_value]] || 0
      )
    end.sort_by { |e| [-e[:type_count], -e[:value_count]] }
  end
  
  # Get popular entity values for a specific type
  def self.popular_entities(entity_type:, year: nil, limit: 20)
    cache_key = "popular_entities_#{entity_type}_#{year || 'all'}_#{limit}"
    cache_duration = Rails.env.production? ? 24.hours : 1.hour
    
    Rails.cache.fetch(cache_key, expires_in: cache_duration) do
      scope = year ? joins(:searchable_item).where(searchable_items: { year: year }) : self
      scope.where(entity_type: entity_type)
           .group(:entity_value)
           .order(Arel.sql('COUNT(*) DESC'))
           .limit(limit)
           .count
    end
  end
end