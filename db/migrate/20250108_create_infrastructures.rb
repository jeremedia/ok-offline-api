class CreateInfrastructures < ActiveRecord::Migration[8.0]
  def change
    # Main infrastructure table
    create_table :infrastructures do |t|
      t.string :uid, null: false
      t.string :name, null: false
      t.string :icon, null: false
      t.string :category, null: false
      t.string :short_description, limit: 500
      
      # Rich content fields
      t.text :history
      t.text :civic_purpose
      t.text :legal_context
      t.text :operations
      
      # Location data
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7
      t.string :address
      
      # Metadata
      t.integer :position
      t.boolean :active, default: true
      t.integer :year
      
      t.timestamps
    end
    
    add_index :infrastructures, :uid, unique: true
    add_index :infrastructures, :category
    add_index :infrastructures, :year
    
    # Multiple locations (for Medical, Rangers, etc.)
    create_table :infrastructure_locations do |t|
      t.references :infrastructure, foreign_key: true, null: false
      t.string :name
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7
      t.string :address
      t.string :notes
      t.integer :position
      t.timestamps
    end
    
    # Timeline events
    create_table :infrastructure_timelines do |t|
      t.references :infrastructure, foreign_key: true, null: false
      t.integer :year
      t.string :event
      t.integer :position
      t.timestamps
    end
    
    # Did you know facts
    create_table :infrastructure_facts do |t|
      t.references :infrastructure, foreign_key: true, null: false
      t.text :content
      t.integer :position
      t.timestamps
    end
    
    # Related links
    create_table :infrastructure_links do |t|
      t.references :infrastructure, foreign_key: true, null: false
      t.string :title
      t.string :url
      t.integer :position
      t.timestamps
    end
    
    # Photos table
    create_table :infrastructure_photos do |t|
      t.references :infrastructure, foreign_key: true, null: false
      t.string :title
      t.string :caption
      t.integer :year
      t.string :photographer_credit
      t.string :photo_url
      t.string :thumbnail_url
      t.integer :position
      t.integer :width
      t.integer :height
      t.string :content_type
      t.integer :file_size
      t.string :photo_type # 'general', 'man_design', 'temple_design', 'historical'
      t.string :theme_name # e.g., "Metamorphoses", "Radical Ritual"
      
      t.timestamps
    end
    
    # Add hero photo reference to infrastructures
    add_column :infrastructures, :hero_photo_id, :bigint
    add_index :infrastructures, :hero_photo_id
    add_foreign_key :infrastructures, :infrastructure_photos, column: :hero_photo_id
  end
end