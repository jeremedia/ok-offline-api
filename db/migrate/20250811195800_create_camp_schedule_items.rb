class CreateCampScheduleItems < ActiveRecord::Migration[8.0]
  def change
    create_table :camp_schedule_items do |t|
      # Basic information
      t.string :title, null: false
      t.text :description
      
      # Date and time fields (using DateTime for precise scheduling)
      t.datetime :start_datetime, null: false
      t.datetime :end_datetime
      
      # Location and logistics
      t.string :location
      t.text :required_supplies
      t.text :notes
      
      # Categorization and status
      t.integer :category, null: false, default: 0
      t.integer :status, null: false, default: 0
      
      # Relationships
      t.references :theme_camp, null: false, foreign_key: true
      t.references :responsible_person, null: true, foreign_key: { to_table: :team_members }
      
      # Integration with Burning Man API events
      t.string :api_event_uid
      
      # Rails timestamps
      t.timestamps
    end
    
    # Indexes for performance
    add_index :camp_schedule_items, :start_datetime
    add_index :camp_schedule_items, :category
    add_index :camp_schedule_items, :status
    add_index :camp_schedule_items, :api_event_uid, unique: true
    add_index :camp_schedule_items, [:theme_camp_id, :start_datetime]
  end
end