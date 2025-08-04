class AddPhilosophicalTextToItemTypes < ActiveRecord::Migration[8.0]
  def up
    # Remove the existing check constraint
    execute <<-SQL
      ALTER TABLE searchable_items DROP CONSTRAINT IF EXISTS searchable_items_item_type_check;
    SQL
    
    # Add the new check constraint with philosophical_text included
    execute <<-SQL
      ALTER TABLE searchable_items ADD CONSTRAINT searchable_items_item_type_check 
      CHECK (item_type IN ('camp', 'art', 'event', 'infrastructure', 'historical_fact', 'timeline_event', 'philosophical_text'));
    SQL
  end
  
  def down
    # Remove the updated constraint
    execute <<-SQL
      ALTER TABLE searchable_items DROP CONSTRAINT IF EXISTS searchable_items_item_type_check;
    SQL
    
    # Restore the original constraint
    execute <<-SQL
      ALTER TABLE searchable_items ADD CONSTRAINT searchable_items_item_type_check 
      CHECK (item_type IN ('camp', 'art', 'event', 'infrastructure', 'historical_fact', 'timeline_event'));
    SQL
  end
end
