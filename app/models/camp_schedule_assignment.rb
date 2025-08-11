class CampScheduleAssignment < ApplicationRecord
  # Associations
  belongs_to :camp_schedule_item
  belongs_to :team_member
  
  # Validations
  validates :team_member_id, uniqueness: { 
    scope: :camp_schedule_item_id,
    message: "is already assigned to this schedule item"
  }
  
  # Custom validations
  validate :team_member_belongs_to_same_camp
  
  # Scopes
  scope :with_notes, -> { where.not(notes: [nil, '']) }
  
  # Instance methods
  def assignment_display
    notes.present? ? "#{team_member.full_name} (#{notes})" : team_member.full_name
  end
  
  private
  
  def team_member_belongs_to_same_camp
    return unless team_member && camp_schedule_item&.theme_camp
    
    unless camp_schedule_item.theme_camp.team_members.include?(team_member)
      errors.add(:team_member, "must be a member of the same camp as the schedule item")
    end
  end
end