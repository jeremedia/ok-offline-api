class CreatePersonalSpaces < ActiveRecord::Migration[8.0]
  def change
    create_table :personal_spaces do |t|
      t.references :team_member, null: false, foreign_key: true
      t.string :space_type
      t.decimal :width
      t.decimal :height
      t.decimal :depth
      t.boolean :needs_power
      t.integer :power_draw
      t.text :comments
      t.decimal :map_x_position
      t.decimal :map_y_position
      t.decimal :rotation
      t.boolean :is_confirmed

      t.timestamps
    end
  end
end
