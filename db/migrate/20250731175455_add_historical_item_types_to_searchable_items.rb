class AddHistoricalItemTypesToSearchableItems < ActiveRecord::Migration[8.0]
  def up
    # Add a check constraint to ensure item_type is one of the allowed values
    execute <<-SQL
      ALTER TABLE searchable_items
      DROP CONSTRAINT IF EXISTS searchable_items_item_type_check;
      
      ALTER TABLE searchable_items
      ADD CONSTRAINT searchable_items_item_type_check
      CHECK (item_type IN ('camp', 'art', 'event', 'infrastructure', 'historical_fact', 'timeline_event'));
    SQL
  end
  
  def down
    # Revert to original constraint
    execute <<-SQL
      ALTER TABLE searchable_items
      DROP CONSTRAINT IF EXISTS searchable_items_item_type_check;
      
      ALTER TABLE searchable_items
      ADD CONSTRAINT searchable_items_item_type_check
      CHECK (item_type IN ('camp', 'art', 'event'));
    SQL
  end
end
