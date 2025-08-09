class Infrastructure < ApplicationRecord
  # Associations
  has_many :locations, -> { order(:position) }, 
           class_name: 'InfrastructureLocation', 
           dependent: :destroy
  has_many :timeline_events, -> { order(:year) }, 
           class_name: 'InfrastructureTimeline', 
           dependent: :destroy
  has_many :facts, -> { order(:position) }, 
           class_name: 'InfrastructureFact', 
           dependent: :destroy
  has_many :links, -> { order(:position) }, 
           class_name: 'InfrastructureLink', 
           dependent: :destroy
  has_many :photos, -> { order(:position) }, 
           class_name: 'InfrastructurePhoto', 
           dependent: :destroy
  
  belongs_to :hero_photo, 
             class_name: 'InfrastructurePhoto', 
             optional: true
  
  # Active Storage for direct uploads
  has_one_attached :hero_image
  has_many_attached :gallery_images
  
  # Scopes for photos
  has_many :man_photos, -> { where(photo_type: 'man_design').order(:year) },
           class_name: 'InfrastructurePhoto'
  has_many :temple_photos, -> { where(photo_type: 'temple_design').order(:year) },
           class_name: 'InfrastructurePhoto'
  
  # Validations
  validates :uid, :name, :icon, :category, presence: true
  validates :uid, uniqueness: true
  validates :category, inclusion: { 
    in: %w[civic services commerce infrastructure] 
  }
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_category, ->(cat) { where(category: cat) }
  scope :ordered, -> { order(:position, :name) }
  scope :for_year, ->(year) { where(year: [nil, year]) }
  
  # Callbacks
  before_validation :generate_uid, on: :create
  
  # Nested attributes for admin forms
  accepts_nested_attributes_for :locations, :timeline_events, :facts, :links, :photos,
                                allow_destroy: true
  
  # Methods
  def coordinates
    [latitude, longitude] if latitude && longitude
  end
  
  def primary_location
    locations.first || self
  end
  
  def photos_by_year
    photos.group_by(&:year).sort.reverse.to_h
  end
  
  def themed_photos
    photos.where.not(theme_name: nil).group_by(&:theme_name)
  end
  
  private
  
  def generate_uid
    self.uid ||= name.parameterize if name.present?
  end
end