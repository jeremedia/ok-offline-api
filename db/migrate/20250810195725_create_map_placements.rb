class CreateMapPlacements < ActiveRecord::Migration[8.0]
  def change
    create_table :map_placements do |t|
      t.references :camp_map, null: false, foreign_key: true
      t.string :placement_type
      t.string :name
      t.text :description
      t.decimal :x_position
      t.decimal :y_position
      t.decimal :rotation
      t.decimal :width
      t.decimal :height
      t.integer :assigned_to_id

      t.timestamps
    end
  end
end
