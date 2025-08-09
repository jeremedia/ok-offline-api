class Theme < ApplicationRecord
  # Validations
  validates :theme_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :colors, presence: true
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }
  
  # JSON serialization (columns are already JSON type, no parsing needed)
  def colors_json
    colors || {}
  end
  
  def typography_json
    typography || {}
  end
  
  # Convert to the format expected by the frontend
  def to_theme_format
    {
      id: theme_id,
      name: name,
      description: description,
      colors: colors_json,
      typography: typography_json || default_typography
    }
  end
  
  private
  
  def default_typography
    {
      fontFamily: 'Berkeley Mono, monospace',
      fontSize: '14px',
      lineHeight: '1.4',
      letterSpacing: '0px'
    }
  end
end