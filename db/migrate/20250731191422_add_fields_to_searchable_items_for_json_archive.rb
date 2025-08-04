class AddFieldsToSearchableItemsForJsonArchive < ActiveRecord::Migration[8.0]
  def change
    # Add fields needed for JSON Archive data
    add_column :searchable_items, :artist, :string
    add_column :searchable_items, :event_type, :string
    add_column :searchable_items, :camp_id, :string
    
    # Add indexes for better query performance
    add_index :searchable_items, :artist
    add_index :searchable_items, :event_type
    add_index :searchable_items, :camp_id
    add_index :searchable_items, [:year, :item_type]
  end
end