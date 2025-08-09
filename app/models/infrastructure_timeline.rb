class InfrastructureTimeline < ApplicationRecord
  belongs_to :infrastructure
  
  validates :year, :event, presence: true
  validates :year, numericality: { 
    greater_than_or_equal_to: 1986,
    less_than_or_equal_to: Date.current.year + 1
  }
end