class SearchQuery < ApplicationRecord
  # Validations
  validates :query, presence: true
  validates :search_type, inclusion: { 
    in: %w[vector hybrid entity keyword], 
    allow_nil: true 
  }
  
  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(search_type: type) }
  scope :successful, -> { where("result_count > 0") }
  
  # Analytics methods
  def self.popular_queries(limit: 10, days: 7)
    where("created_at > ?", days.days.ago)
      .group(:query)
      .order('COUNT(id) DESC')
      .limit(limit)
      .count
  end
  
  def self.average_execution_time(search_type: nil)
    scope = search_type ? by_type(search_type) : all
    scope.average(:execution_time)
  end
  
  def self.search_success_rate
    total = count
    successful_count = successful.count
    return 0 if total == 0
    
    (successful_count.to_f / total * 100).round(2)
  end
end