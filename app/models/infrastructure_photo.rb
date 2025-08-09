class InfrastructurePhoto < ApplicationRecord
  belongs_to :infrastructure
  has_one :infrastructure_as_hero, 
          class_name: 'Infrastructure', 
          foreign_key: 'hero_photo_id',
          dependent: :nullify
  
  # Active Storage attachment
  has_one_attached :image
  
  # Validations
  validates :photo_url, presence: true, unless: :image_attached?
  validates :photo_type, inclusion: { 
    in: %w[general man_design temple_design historical aerial],
    allow_nil: true
  }
  
  # Scopes
  scope :by_year, ->(year) { where(year: year) }
  scope :man_designs, -> { where(photo_type: 'man_design') }
  scope :temple_designs, -> { where(photo_type: 'temple_design') }
  scope :with_theme, -> { where.not(theme_name: nil) }
  
  # Generate responsive image URLs
  def responsive_urls
    base_url = image_attached? ? rails_blob_url(image) : photo_url
    
    {
      thumbnail: thumbnail_url || base_url,
      small: cdn_transform(base_url, width: 400),
      medium: cdn_transform(base_url, width: 800),
      large: cdn_transform(base_url, width: 1200),
      original: base_url
    }
  end
  
  # Get the primary URL for this photo
  def primary_url
    image_attached? ? rails_blob_url(image) : photo_url
  end
  
  # Check if Active Storage image is attached
  def image_attached?
    image.attached?
  end
  
  private
  
  def cdn_transform(url, width:)
    # For Active Storage URLs, use variant processing
    if image_attached?
      # Return a variant URL for Active Storage
      rails_representation_url(image.variant(resize_to_limit: [width, nil]))
    else
      # For external URLs, just return the original
      # Later implement based on your CDN (Cloudinary, ImageKit, etc.)
      url
    end
  end
  
  # Include URL helpers for Active Storage
  include Rails.application.routes.url_helpers
end