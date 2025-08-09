class InfrastructureFact < ApplicationRecord
  belongs_to :infrastructure
  
  validates :content, presence: true
end