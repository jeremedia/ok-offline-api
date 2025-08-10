class GltfModel < ApplicationRecord
  has_many :personal_spaces, dependent: :nullify
  has_many :map_placements, dependent: :nullify

  # Active Storage for model files
  has_one_attached :model_file
  has_one_attached :preview_image

  # Validations
  validates :name, presence: true, uniqueness: true
  validates :category, inclusion: { in: %w[tent rv structure equipment vehicle] }
  validates :default_width, :default_height, :default_depth, 
            presence: true, numericality: { greater_than: 0 }

  # Scopes
  scope :by_category, ->(category) { where(category: category) }
  scope :with_preview, -> { joins(:preview_image_attachment) }

  # Methods
  def default_volume
    default_width * default_height * default_depth
  end

  def default_footprint
    default_width * default_depth
  end

  def display_dimensions
    "#{default_width}' × #{default_depth}' × #{default_height}'"
  end

  def model_available?
    model_file.attached?
  end

  def preview_available?
    preview_image.attached?
  end
end
