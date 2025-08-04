class CreateBurningManYears < ActiveRecord::Migration[8.0]
  def change
    create_table :burning_man_years do |t|
      t.integer :year
      t.string :theme
      t.text :theme_statement
      t.integer :attendance
      t.string :location
      t.jsonb :dates
      t.integer :man_height
      t.jsonb :ticket_prices
      t.text :notable_events, array: true, default: []
      t.jsonb :city_layout, default: {}
      t.jsonb :infrastructure_config, default: {}
      t.jsonb :timeline_events, default: []
      t.jsonb :census_data, default: {}
      t.jsonb :location_details, default: {}
      t.datetime :man_burn_date
      t.datetime :temple_burn_date

      t.timestamps
    end
    add_index :burning_man_years, :year, unique: true
  end
end
