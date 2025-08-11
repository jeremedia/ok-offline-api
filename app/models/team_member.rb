class TeamMember < ApplicationRecord
  belongs_to :theme_camp
  has_one :personal_space, dependent: :destroy
  has_many :map_placements, foreign_key: :assigned_to_id, dependent: :nullify
  
  # Schedule associations
  has_many :camp_schedule_assignments, dependent: :destroy
  has_many :assigned_schedule_items, through: :camp_schedule_assignments, source: :camp_schedule_item
  has_many :responsible_schedule_items, class_name: 'CampScheduleItem', foreign_key: :responsible_person_id, dependent: :nullify

  # Active Storage for photo
  has_one_attached :photo

  # Validations
  validates :first_name, :last_name, :email, presence: true
  validates :email, uniqueness: { scope: :theme_camp_id }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: %w[camp_lead veteran virgin day_visitor] }

  # Scopes
  scope :verified, -> { where(is_verified: true) }
  scope :by_role, ->(role) { where(role: role) }
  scope :arriving_on, ->(date) { where(arrival_date: date) }

  # Methods
  def full_name
    "#{first_name} #{last_name}"
  end

  def display_name
    playa_name.present? ? "#{playa_name} (#{full_name})" : full_name
  end

  def duration_days
    return nil unless arrival_date && departure_date
    (departure_date - arrival_date).to_i + 1
  end

  def skills_list
    skills&.split(',')&.map(&:strip) || []
  end

  def needs_space?
    personal_space.nil?
  end
  
  # Schedule helper methods
  def upcoming_assignments
    assigned_schedule_items.upcoming.chronological
  end
  
  def upcoming_responsibilities
    responsible_schedule_items.upcoming.chronological
  end
  
  def schedule_conflicts_for(start_datetime, end_datetime)
    assigned_schedule_items.where(
      "(start_datetime < ? AND (end_datetime IS NULL OR end_datetime > ?)) OR (start_datetime >= ? AND start_datetime < ?)",
      end_datetime, start_datetime, start_datetime, end_datetime
    ).active
  end
  
  def available_for?(start_datetime, end_datetime)
    schedule_conflicts_for(start_datetime, end_datetime).empty?
  end
end
