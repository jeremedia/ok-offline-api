class InfrastructureLocation < ApplicationRecord
  belongs_to :infrastructure
  
  validates :name, presence: true
  validates :latitude, :longitude, presence: true
  
  def coordinates
    [latitude, longitude]
  end
end