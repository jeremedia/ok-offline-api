class SearchEntity < ApplicationRecord
  # Associations
  belongs_to :searchable_item
  
  # Validations
  validates :entity_type, presence: true, inclusion: { 
    in: %w[location activity theme time person] 
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
  
  # Class methods for entity-based search
  def self.search_by_entities(entity_values)
    joins(:searchable_item)
      .where(entity_value: entity_values)
      .group('searchable_items.id')
      .order('COUNT(search_entities.id) DESC')
      .select('searchable_items.*, COUNT(search_entities.id) as entity_match_count')
  end
end