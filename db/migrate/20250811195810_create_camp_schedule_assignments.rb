class CreateCampScheduleAssignments < ActiveRecord::Migration[8.0]
  def change
    create_table :camp_schedule_assignments do |t|
      # Foreign keys for the many-to-many relationship
      t.references :camp_schedule_item, null: false, foreign_key: true
      t.references :team_member, null: false, foreign_key: true
      
      # Optional assignment-specific fields
      t.text :notes # Role-specific notes like "Cleanup lead" or "Greeter"
      
      # Rails timestamps
      t.timestamps
    end
    
    # Ensure no duplicate assignments (compound index covers both columns)
    add_index :camp_schedule_assignments, [:camp_schedule_item_id, :team_member_id], 
              unique: true, 
              name: 'index_schedule_assignments_unique'
  end
end