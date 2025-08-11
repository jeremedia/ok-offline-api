class FixCampScheduleAssignmentsIndexes < ActiveRecord::Migration[8.0]
  def up
    # Remove the duplicate index if it exists
    remove_index :camp_schedule_assignments, :team_member_id if index_exists?(:camp_schedule_assignments, :team_member_id)
    
    # Add it back only if it doesn't exist
    add_index :camp_schedule_assignments, :team_member_id unless index_exists?(:camp_schedule_assignments, :team_member_id)
  end
  
  def down
    # No need to do anything on rollback
  end
end