class CampMap < ApplicationRecord
  belongs_to :theme_camp
  has_many :map_placements, dependent: :destroy

  # Active Storage for map image
  has_one_attached :map_image

  # Validations
  validates :total_width, :total_depth, presence: true, numericality: { greater_than: 0 }
  validates :bm_address, presence: true
  validates :gps_latitude, :gps_longitude, numericality: true, allow_nil: true
  validates :scale_factor, numericality: { greater_than: 0 }, allow_nil: true
  validates :orientation, numericality: { in: 0..360 }, allow_nil: true

  # Methods
  def total_area
    total_width * total_depth
  end

  def gps_coordinates
    return nil unless gps_latitude && gps_longitude
    [gps_latitude, gps_longitude]
  end

  def placement_density
    return 0 if total_area.zero?
    map_placements.count / total_area * 100
  end

  def available_space
    used_area = map_placements.sum { |p| (p.width || 0) * (p.height || 0) }
    total_area - used_area
  end
end
