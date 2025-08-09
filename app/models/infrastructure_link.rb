class InfrastructureLink < ApplicationRecord
  belongs_to :infrastructure
  
  validates :title, :url, presence: true
  validates :url, format: { 
    with: URI::regexp(%w[http https]),
    message: "must be a valid URL"
  }
end