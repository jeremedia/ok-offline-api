class CreateThemeCamps < ActiveRecord::Migration[8.0]
  def change
    create_table :theme_camps do |t|
      t.string :name
      t.text :description
      t.string :burning_man_uid
      t.integer :year
      t.string :slug
      t.boolean :is_active
      t.integer :camp_lead_id

      t.timestamps
    end
    add_index :theme_camps, :slug, unique: true
  end
end
