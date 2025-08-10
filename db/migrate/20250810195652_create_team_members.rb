class CreateTeamMembers < ActiveRecord::Migration[8.0]
  def change
    create_table :team_members do |t|
      t.string :first_name
      t.string :last_name
      t.string :playa_name
      t.string :email
      t.string :phone
      t.string :role
      t.date :arrival_date
      t.date :departure_date
      t.json :emergency_contact
      t.text :dietary_restrictions
      t.text :skills
      t.boolean :is_verified
      t.references :theme_camp, null: false, foreign_key: true

      t.timestamps
    end
  end
end
