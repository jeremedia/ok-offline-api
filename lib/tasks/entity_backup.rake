namespace :search do
  desc "Backup entity values before normalization"
  task backup_entities: :environment do
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    backup_file = Rails.root.join("tmp", "entity_backup_#{timestamp}.csv")
    
    puts "📦 Backing up entity values to: #{backup_file}"
    
    require 'csv'
    
    CSV.open(backup_file, "wb") do |csv|
      csv << ["id", "searchable_item_id", "entity_type", "entity_value", "confidence", "created_at", "updated_at"]
      
      SearchEntity.find_each do |entity|
        csv << [
          entity.id,
          entity.searchable_item_id,
          entity.entity_type,
          entity.entity_value,
          entity.confidence,
          entity.created_at,
          entity.updated_at
        ]
      end
    end
    
    count = SearchEntity.count
    puts "✅ Backed up #{count} entities to #{backup_file}"
    puts
    puts "To restore from this backup, use:"
    puts "  rails search:restore_entities[#{backup_file}]"
  end
  
  desc "Restore entity values from backup"
  task :restore_entities, [:backup_file] => :environment do |_, args|
    unless args[:backup_file] && File.exist?(args[:backup_file])
      puts "❌ Error: Please provide a valid backup file path"
      puts "Usage: rails search:restore_entities[/path/to/backup.csv]"
      exit 1
    end
    
    puts "🔄 Restoring entities from: #{args[:backup_file]}"
    
    require 'csv'
    restored = 0
    
    CSV.foreach(args[:backup_file], headers: true) do |row|
      entity = SearchEntity.find_by(id: row["id"])
      if entity
        entity.update_column(:entity_value, row["entity_value"])
        restored += 1
      end
    end
    
    # Clear caches after restore
    Rails.cache.clear
    
    puts "✅ Restored #{restored} entities"
  end
end