namespace :hrm do
  desc "Export graph data for HRM training"
  task export_graph: :environment do
    require 'json'
    require 'fileutils'
    
    output_dir = ENV['OUTPUT_DIR'] || "/Volumes/jer4TBv3/hrm/hrm-mlx/data/burning_man_graph/raw"
    FileUtils.mkdir_p(output_dir)
    
    puts "🔥 Starting Burning Man graph data extraction to #{output_dir}..."
    
    # Extract entities by pool
    puts "📊 Extracting entities by pool..."
    pools = SearchEntity.distinct.pluck(:entity_type).select { |t| t&.start_with?('pool_') }
    
    entities_data = {}
    
    pools.each do |pool|
      pool_name = pool.sub('pool_', '')
      entities = SearchEntity.where(entity_type: pool)
                            .group(:entity_value)
                            .count
                            .sort_by { |_, count| -count }
      
      entities_data[pool_name] = entities.map do |entity_value, count|
        {
          name: entity_value,
          pool: pool_name,
          frequency: count,
          items: SearchEntity.where(entity_type: pool, entity_value: entity_value)
                             .limit(10) # Limit to avoid huge files
                             .pluck(:searchable_item_id)
        }
      end
      
      puts "  - #{pool_name}: #{entities.size} unique entities"
    end
    
    File.write("#{output_dir}/entities_by_pool.json", JSON.pretty_generate(entities_data))
    
    # Extract relationships
    puts "🔗 Extracting entity co-occurrences..."
    
    relationships = []
    
    # Sample items with multiple entities
    item_ids = SearchEntity.select(:searchable_item_id)
                          .where("entity_type LIKE 'pool_%'")
                          .group(:searchable_item_id)
                          .having('COUNT(DISTINCT entity_type) > 1')
                          .limit(1000)
                          .pluck(:searchable_item_id)
    
    puts "  Processing #{item_ids.size} items with cross-pool entities..."
    
    # For each item, create relationships between entity pairs from different pools
    item_ids.each do |item_id|
      entities = SearchEntity.where(searchable_item_id: item_id)
                            .where("entity_type LIKE 'pool_%'")
                            .pluck(:entity_type, :entity_value, :confidence)
      
      # Create cross-pool pairs only
      entities.combination(2).each do |e1, e2|
        if e1[0] != e2[0] # Different pools
          relationships << {
            source: { name: e1[1], pool: e1[0].sub('pool_', ''), confidence: e1[2] },
            target: { name: e2[1], pool: e2[0].sub('pool_', ''), confidence: e2[2] },
            item_id: item_id
          }
        end
      end
    end
    
    # Aggregate relationships
    aggregated = relationships.group_by { |r| [r[:source][:name], r[:target][:name]].sort }
                             .map do |key, rels|
      source = rels.first[:source]
      target = rels.first[:target]
      # Ensure consistent ordering
      if source[:name] > target[:name]
        source, target = target, source
      end
      
      {
        source: source,
        target: target,
        count: rels.size,
        confidence: (rels.map { |r| [r[:source][:confidence] || 0.5, r[:target][:confidence] || 0.5].min }.sum / rels.size.to_f).round(3)
      }
    end.sort_by { |r| -r[:count] }.first(5000) # Top 5000 relationships
    
    File.write("#{output_dir}/entity_relationships.json", JSON.pretty_generate(aggregated))
    puts "  Found #{aggregated.size} unique cross-pool relationships"
    
    # Extract bridge entities
    puts "🌉 Extracting bridge entities..."
    
    bridge_query = <<-SQL
      SELECT entity_value, 
             array_agg(DISTINCT entity_type) as pools,
             COUNT(*) as total_frequency
      FROM search_entities
      WHERE entity_type LIKE 'pool_%'
      GROUP BY entity_value
      HAVING COUNT(DISTINCT entity_type) > 1
      ORDER BY COUNT(DISTINCT entity_type) DESC, COUNT(*) DESC
      LIMIT 1000
    SQL
    
    bridges = ActiveRecord::Base.connection.execute(bridge_query).map do |row|
      pools = row['pools'].gsub(/[{}]/, '').split(',').map { |p| p.strip.sub('pool_', '') }
      {
        name: row['entity_value'],
        pools: pools,
        pool_count: pools.size,
        total_frequency: row['total_frequency'],
        bridge_power: (pools.size * Math.sqrt(row['total_frequency'])).round(2)
      }
    end
    
    File.write("#{output_dir}/bridge_entities.json", JSON.pretty_generate(bridges))
    puts "  Found #{bridges.size} bridge entities"
    
    # Extract sample items
    puts "📦 Extracting sample items..."
    
    # Use subquery to avoid DISTINCT on JSON columns
    item_ids = SearchEntity.where("entity_type LIKE 'pool_%'")
                          .joins(:searchable_item)
                          .where("searchable_items.year >= 2022")
                          .select(:searchable_item_id)
                          .distinct
                          .limit(2000)
                          .pluck(:searchable_item_id)
    
    items_data = SearchableItem.where(id: item_ids).map do |item|
      {
        id: item.id,
        uid: item.uid,
        name: item.name,
        type: item.item_type,
        year: item.year,
        description: item.description&.truncate(200),
        entities: item.search_entities
                     .where("entity_type LIKE 'pool_%'")
                     .map { |e| 
          {
            pool: e.entity_type&.sub('pool_', ''),
            value: e.entity_value,
            confidence: e.confidence
          }
        }
      }
    end
    
    File.write("#{output_dir}/items_sample.json", JSON.pretty_generate(items_data))
    puts "  Exported #{items_data.size} items"
    
    # Graph statistics
    puts "📈 Extracting graph statistics..."
    
    stats = {
      total_items: SearchableItem.count,
      total_entities: SearchEntity.where("entity_type LIKE 'pool_%'").count,
      unique_entities: SearchEntity.where("entity_type LIKE 'pool_%'").distinct.count(:entity_value),
      pools: SearchEntity.where("entity_type LIKE 'pool_%'")
                        .group(:entity_type)
                        .count
                        .transform_keys { |k| k.sub('pool_', '') },
      years: SearchableItem.group(:year).count,
      item_types: SearchableItem.group(:item_type).count,
      cross_pool_items: SearchEntity.select(:searchable_item_id)
                                   .where("entity_type LIKE 'pool_%'")
                                   .group(:searchable_item_id)
                                   .having('COUNT(DISTINCT entity_type) > 1')
                                   .count.size
    }
    
    File.write("#{output_dir}/graph_stats.json", JSON.pretty_generate(stats))
    
    puts "✅ Export complete! Files saved to #{output_dir}"
    puts "   - entities_by_pool.json"
    puts "   - entity_relationships.json" 
    puts "   - bridge_entities.json"
    puts "   - items_sample.json"
    puts "   - graph_stats.json"
  end
end