class UpdateSearchableItemsItemTypeConstraint < ActiveRecord::Migration[8.0]
  def up
    # Remove existing constraint
    execute "ALTER TABLE searchable_items DROP CONSTRAINT IF EXISTS searchable_items_item_type_check"
    
    # Add new constraint with expanded item types (includes existing types + biographical types)
    execute <<-SQL
      ALTER TABLE searchable_items ADD CONSTRAINT searchable_items_item_type_check 
      CHECK (item_type IN ('camp', 'art', 'event', 'experience_story', 'historical_fact', 'infrastructure', 'practical_guide', 'timeline_event', 'essay', 'speech', 'philosophical_text', 'manifesto', 'interview', 'letter', 'note', 'theme_essay', 'policy_essay'))
    SQL
  end

  def down
    # Remove the expanded constraint
    execute "ALTER TABLE searchable_items DROP CONSTRAINT IF EXISTS searchable_items_item_type_check"
    
    # Restore original constraint
    execute <<-SQL
      ALTER TABLE searchable_items ADD CONSTRAINT searchable_items_item_type_check 
      CHECK (item_type IN ('camp', 'art', 'event'))
    SQL
  end
end