class AddExperiencePracticalToItemTypes < ActiveRecord::Migration[8.0]
  def up
    # Remove old constraint
    execute <<-SQL
      ALTER TABLE searchable_items 
      DROP CONSTRAINT IF EXISTS searchable_items_item_type_check;
    SQL
    
    # Add new constraint with additional types
    execute <<-SQL
      ALTER TABLE searchable_items 
      ADD CONSTRAINT searchable_items_item_type_check 
      CHECK (item_type IN ('camp', 'art', 'event', 'infrastructure', 'historical_fact', 'timeline_event', 'philosophical_text', 'experience_story', 'practical_guide'));
    SQL
  end
  
  def down
    # Remove constraint
    execute <<-SQL
      ALTER TABLE searchable_items 
      DROP CONSTRAINT IF EXISTS searchable_items_item_type_check;
    SQL
    
    # Add back original constraint
    execute <<-SQL
      ALTER TABLE searchable_items 
      ADD CONSTRAINT searchable_items_item_type_check 
      CHECK (item_type IN ('camp', 'art', 'event', 'infrastructure', 'historical_fact', 'timeline_event', 'philosophical_text'));
    SQL
  end
end