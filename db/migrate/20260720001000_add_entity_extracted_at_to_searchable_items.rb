class AddEntityExtractedAtToSearchableItems < ActiveRecord::Migration[8.0]
  def change
    add_column :searchable_items, :entity_extracted_at, :datetime
    add_index :searchable_items, [ :year, :entity_extracted_at ]
  end
end
