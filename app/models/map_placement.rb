class MapPlacement < ApplicationRecord
  belongs_to :camp_map
  belongs_to :gltf_model, optional: true
  belongs_to :assigned_to, class_name: "TeamMember", optional: true

  # Validations
  validates :placement_type, inclusion: { in: %w[personal_space communal_space equipment vehicle landmark] }
  validates :name, presence: true
  validates :x_position, :y_position, presence: true, numericality: true
  validates :rotation, numericality: { in: 0..360 }, allow_nil: true
  validates :width, :height, numericality: { greater_than: 0 }, allow_nil: true

  # Scopes
  scope :by_type, ->(type) { where(placement_type: type) }
  scope :assigned, -> { where.not(assigned_to_id: nil) }
  scope :unassigned, -> { where(assigned_to_id: nil) }

  # Methods
  def area
    return nil unless width && height
    width * height
  end

  def position
    [x_position, y_position]
  end

  def assigned?
    assigned_to_id.present?
  end

  def display_name
    assigned? ? "#{name} (#{assigned_to.display_name})" : name
  end

  def bounds
    return nil unless width && height
    {
      min_x: x_position - width / 2,
      max_x: x_position + width / 2,
      min_y: y_position - height / 2,
      max_y: y_position + height / 2
    }
  end
end
