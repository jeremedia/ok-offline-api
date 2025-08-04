namespace :search do
  desc "Normalize existing entity values using EntityNormalizationService"
  task normalize_entities: :environment do
    puts "🔧 Starting entity normalization..."
    puts "This will update existing entities to use normalized values"
    puts
    
    # Initialize service and counters
    service = Search::EntityNormalizationService.new
    total_processed = 0
    total_updated = 0
    changes_by_type = Hash.new { |h, k| h[k] = Hash.new(0) }
    
    # Process entities in batches to avoid memory issues
    SearchEntity.find_each(batch_size: 1000) do |entity|
      total_processed += 1
      
      # Get normalized value
      original_value = entity.entity_value
      normalized_value = service.normalize_entity(entity.entity_type, original_value)
      
      # Update if changed
      if original_value != normalized_value
        entity.update!(entity_value: normalized_value)
        total_updated += 1
        changes_by_type[entity.entity_type]["#{original_value} → #{normalized_value}"] += 1
        
        # Log progress every 100 updates
        if total_updated % 100 == 0
          puts "  Processed #{total_processed} entities, updated #{total_updated}..."
        end
      end
    end
    
    # Clear caches after normalization
    Rails.cache.clear
    
    # Show summary
    puts
    puts "✅ Normalization complete!"
    puts "   Total entities processed: #{total_processed}"
    puts "   Total entities updated: #{total_updated}"
    puts
    
    if total_updated > 0
      puts "📊 Changes by entity type:"
      changes_by_type.each do |entity_type, changes|
        puts "\n   #{entity_type.capitalize}:"
        changes.sort_by { |_, count| -count }.first(10).each do |change, count|
          puts "     #{change} (#{count} occurrences)"
        end
        if changes.size > 10
          puts "     ... and #{changes.size - 10} more changes"
        end
      end
    end
    
    # Show top entities after normalization
    puts "\n🏆 Top 10 activities after normalization:"
    SearchEntity.where(entity_type: 'activity')
      .group(:entity_value)
      .order(Arel.sql('COUNT(*) DESC'))
      .limit(10)
      .count
      .each do |activity, count|
        puts "   #{activity}: #{count}"
      end
  end
  
  desc "Preview entity normalization without making changes"
  task preview_normalization: :environment do
    puts "👀 Previewing entity normalization (no changes will be made)..."
    puts
    
    service = Search::EntityNormalizationService.new
    changes_preview = Hash.new { |h, k| h[k] = [] }
    
    # Sample entities to preview
    SearchEntity.find_each(batch_size: 1000) do |entity|
      original_value = entity.entity_value
      normalized_value = service.normalize_entity(entity.entity_type, original_value)
      
      if original_value != normalized_value
        changes_preview[entity.entity_type] << {
          original: original_value,
          normalized: normalized_value
        }
      end
    end
    
    # Show preview
    changes_preview.each do |entity_type, changes|
      unique_changes = changes.uniq
      puts "#{entity_type.capitalize} (#{changes.size} total changes, #{unique_changes.size} unique):"
      
      # Group by normalized value to show consolidation
      grouped = unique_changes.group_by { |c| c[:normalized] }
      grouped.sort_by { |_, group| -group.size }.first(10).each do |normalized, group|
        if group.size > 1
          puts "  '#{normalized}' ← [#{group.map { |c| "'#{c[:original]}'" }.join(', ')}]"
        else
          puts "  '#{normalized}' ← '#{group.first[:original]}'"
        end
      end
      
      if grouped.size > 10
        puts "  ... and #{grouped.size - 10} more normalizations"
      end
      puts
    end
  end
  
  desc "Rollback entity normalization (requires backup)"
  task rollback_normalization: :environment do
    puts "⚠️  This task requires a database backup to rollback from."
    puts "Entity normalization cannot be automatically reversed without original values."
    puts
    puts "To rollback:"
    puts "1. Restore your database from a backup taken before normalization"
    puts "2. Or manually update specific entities if you know the original values"
  end
end