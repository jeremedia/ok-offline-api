class PersonalSpace < ApplicationRecord
  belongs_to :team_member
  belongs_to :gltf_model, optional: true

  # Validations
  validates :space_type, inclusion: { in: %w[tent rv trailer yurt structure vehicle] }
  validates :width, :depth, presence: true, numericality: { greater_than: 0 }
  validates :height, numericality: { greater_than: 0 }, allow_nil: true
  validates :power_draw, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Scopes
  scope :needs_power, -> { where(needs_power: true) }
  scope :confirmed, -> { where(is_confirmed: true) }
  scope :by_type, ->(type) { where(space_type: type) }

  # Methods
  def area
    width * depth
  end

  def volume
    return nil unless height
    area * height
  end

  def display_dimensions
    if height
      "#{width}' × #{depth}' × #{height}'"
    else
      "#{width}' × #{depth}'"
    end
  end

  def power_description
    return "No power needed" unless needs_power?
    power_draw ? "#{power_draw}W" : "Power needed (TBD)"
  end
end
