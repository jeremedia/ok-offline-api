class ThemeCamp < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged

  # Associations
  has_many :team_members, dependent: :destroy
  has_one :camp_map, dependent: :destroy
  has_many :camp_schedule_items, dependent: :destroy
  belongs_to :camp_lead, class_name: "TeamMember", optional: true

  # Validations
  validates :name, presence: true, uniqueness: { scope: :year }
  validates :year, presence: true
  validates :slug, uniqueness: true

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :for_year, ->(year) { where(year: year) }

  # Methods
  def camp_lead_name
    camp_lead&.full_name
  end

  def member_count
    team_members.count
  end

  def should_generate_new_friendly_id?
    name_changed? || super
  end

  def normalize_friendly_id(text)
    text.to_s.downcase.gsub(/[^a-z0-9]+/, '-').chomp('-')
  end
  
  # Schedule helper methods
  def upcoming_schedule_items
    camp_schedule_items.upcoming.chronological
  end
  
  def schedule_items_for_date(date)
    camp_schedule_items.for_date_range(date, date).chronological
  end
  
  def public_events
    camp_schedule_items.public_event.active.chronological
  end
end
