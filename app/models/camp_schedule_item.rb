class CampScheduleItem < ApplicationRecord
  # Associations
  belongs_to :theme_camp
  belongs_to :responsible_person, class_name: 'TeamMember', optional: true
  
  has_many :camp_schedule_assignments, dependent: :destroy
  has_many :team_members, through: :camp_schedule_assignments
  
  # Enums
  enum :category, { 
    public_event: 0, 
    meal: 1, 
    arrival: 2, 
    departure: 3, 
    service: 4, 
    meeting: 5 
  }
  
  enum :status, { 
    happening: 0,  # Default - scheduled and happening
    canceled: 1,   # Event was canceled
    happened: 2,   # Event completed successfully  
    skipped: 3,    # Event was skipped/postponed
    draft: 4       # Draft/planning status
  }
  
  # Validations
  validates :title, presence: true, length: { maximum: 255 }
  validates :category, presence: true
  validates :status, presence: true
  validates :start_datetime, presence: true
  validates :api_event_uid, uniqueness: { allow_blank: true }
  
  # Custom validations
  validate :end_datetime_after_start_datetime
  validate :responsible_person_belongs_to_camp
  
  # Scopes
  scope :upcoming, -> { where('start_datetime > ?', Time.current) }
  scope :past, -> { where('start_datetime < ?', Time.current) }
  scope :current, -> { where('start_datetime <= ? AND (end_datetime IS NULL OR end_datetime >= ?)', Time.current, Time.current) }
  scope :by_category, ->(category) { where(category: category) }
  scope :active, -> { where.not(status: :canceled) }
  scope :chronological, -> { order(:start_datetime) }
  scope :for_date_range, ->(start_date, end_date) { where(start_datetime: start_date.beginning_of_day..end_date.end_of_day) }
  
  # Instance methods
  def duration_minutes
    return nil unless end_datetime && start_datetime
    ((end_datetime - start_datetime) / 1.minute).round
  end
  
  def duration_hours
    return nil unless duration_minutes
    (duration_minutes / 60.0).round(1)
  end
  
  def is_current?
    Time.current >= start_datetime && (end_datetime.nil? || Time.current <= end_datetime)
  end
  
  def is_upcoming?
    start_datetime > Time.current
  end
  
  def is_past?
    start_datetime < Time.current
  end
  
  def start_date
    start_datetime&.to_date
  end
  
  def start_time
    start_datetime&.strftime('%H:%M')
  end
  
  def end_time
    end_datetime&.strftime('%H:%M')
  end
  
  # Display helpers
  def category_display
    category.humanize
  end
  
  def status_display
    status.humanize
  end
  
  def assigned_member_names
    team_members.pluck(:first_name, :last_name).map { |first, last| "#{first} #{last}" }
  end
  
  def responsible_person_name
    responsible_person&.full_name
  end
  
  # Class methods
  def self.for_camp(camp_slug)
    joins(:theme_camp).where(theme_camps: { slug: camp_slug })
  end
  
  def self.search(query)
    return all if query.blank?
    
    where(
      "title ILIKE :query OR description ILIKE :query OR location ILIKE :query OR notes ILIKE :query",
      query: "%#{query}%"
    )
  end
  
  private
  
  def end_datetime_after_start_datetime
    return unless start_datetime && end_datetime
    
    if end_datetime <= start_datetime
      errors.add(:end_datetime, "must be after start time")
    end
  end
  
  def responsible_person_belongs_to_camp
    return unless responsible_person && theme_camp
    
    unless theme_camp.team_members.include?(responsible_person)
      errors.add(:responsible_person, "must be a member of this camp")
    end
  end
end