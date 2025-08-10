class CreateCampMaps < ActiveRecord::Migration[8.0]
  def change
    create_table :camp_maps do |t|
      t.references :theme_camp, null: false, foreign_key: true
      t.decimal :total_width
      t.decimal :total_depth
      t.string :bm_address
      t.decimal :gps_latitude
      t.decimal :gps_longitude
      t.decimal :scale_factor
      t.decimal :orientation

      t.timestamps
    end
  end
end
