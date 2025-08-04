class AddCommonFieldsToSearchableItems < ActiveRecord::Migration[8.0]
  def change
    # Add common fields based on JSON Archive analysis
    # These fields appear in 100% of items or are critical for display/search
    
    add_column :searchable_items, :url, :string
    add_column :searchable_items, :hometown, :string
    add_column :searchable_items, :location_string, :string
    
    # Add indexes for commonly queried fields
    add_index :searchable_items, :url
    add_index :searchable_items, :hometown
    add_index :searchable_items, :location_string
    
    # Also add a composite index for location-based queries
    add_index :searchable_items, [:year, :location_string]
  end
end