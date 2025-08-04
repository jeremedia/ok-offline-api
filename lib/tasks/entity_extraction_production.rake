namespace :entity_extraction do
  desc "Execute production entity extraction for all items needing basic entities"
  task production_batch: :environment do
    puts "=" * 80
    puts "🚀 PRODUCTION ENTITY EXTRACTION BATCH"
    puts "=" * 80
    puts
    
    # Find items that have pool entities but lack basic entities
    # Using pluck to avoid JSON field issues with DISTINCT
    pool_item_ids = SearchableItem.joins(:search_entities)
      .where(search_entities: { 
        entity_type: ["pool_idea", "pool_manifest", "pool_experience", 
                      "pool_relational", "pool_evolutionary", "pool_practical", "pool_emanation"] 
      })
      .distinct
      .pluck(:id)
    
    basic_item_ids = SearchableItem.joins(:search_entities)
      .where(search_entities: { 
        entity_type: ["location", "activity", "theme", "time", "person", 
                      "item_type", "contact", "organizational", "service", 
                      "schedule", "requirement"] 
      })
      .distinct
      .pluck(:id)
    
    # Items that have pool entities but not basic entities
    items_needing_extraction_ids = pool_item_ids - basic_item_ids
    total_items = items_needing_extraction_ids.count
    puts "📊 Items needing basic entity extraction: #{total_items}"
    
    if total_items == 0
      puts "✅ No items need entity extraction!"
      exit
    end
    
    # Show cost estimate - get a sample of items for estimation
    sample_items = SearchableItem.where(id: items_needing_extraction_ids.first(100))
    service = Search::BatchBasicEntityExtractionService.new
    
    # Estimate based on sample, then extrapolate
    sample_estimate = service.estimate_batch_cost(sample_items)
    multiplier = total_items.to_f / sample_items.count
    
    total_estimated_tokens = (sample_estimate[:estimated_total_tokens] * multiplier).to_i
    total_estimated_cost = (sample_estimate[:estimated_cost].gsub('$','').to_f * multiplier)
    
    puts "\n💰 Cost Estimate for #{total_items} items:"
    puts "   Estimated tokens: #{total_estimated_tokens.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts "   Estimated cost: $#{'%.2f' % total_estimated_cost} (with 50% batch discount)"
    puts "   Cost per item: $#{'%.6f' % (total_estimated_cost / total_items)}"
    
    print "\n⚠️  Ready to submit #{total_items} items for extraction? (yes/no): "
    response = STDIN.gets.chomp.downcase
    
    unless response == 'yes' || response == 'y'
      puts "❌ Batch cancelled"
      exit
    end
    
    # Process in batches to avoid memory issues
    batch_ids = []
    items_needing_extraction_ids.each_slice(500) do |batch_item_ids|
      # Load items for this batch
      batch_items = SearchableItem.where(id: batch_item_ids)
      
      puts "\n📦 Submitting batch of #{batch_items.count} items..."
      batch_id = service.submit_batch_extraction(batch_items)
      
      if batch_id
        batch_ids << batch_id
        puts "✅ Batch submitted: #{batch_id}"
      else
        puts "❌ Failed to submit batch!"
      end
    end
    
    puts "\n" + "=" * 80
    puts "🎉 PRODUCTION BATCH SUBMISSION COMPLETE!"
    puts "=" * 80
    puts "Total batches submitted: #{batch_ids.count}"
    puts "\nBatch IDs:"
    batch_ids.each { |id| puts "  - #{id}" }
    
    puts "\n📝 Next Steps:"
    puts "1. Monitor progress: rails entity_extraction:monitor"
    puts "2. Webhooks will automatically process completed batches"
    puts "3. Manual processing if needed: rails entity_extraction:process_batch[batch_id]"
    puts "\n✅ Entity extraction is underway!"
  end
  
  desc "Monitor entity extraction batch progress"
  task monitor: :environment do
    active_batches = BatchJob.where(job_type: 'entity_extraction').active.recent
    
    if active_batches.empty?
      puts "No active entity extraction batches"
      return
    end
    
    puts "🔄 Active Entity Extraction Batches:"
    puts
    
    service = Search::BatchBasicEntityExtractionService.new
    
    active_batches.each do |batch_job|
      status = service.check_batch_status(batch_job.batch_id)
      
      puts "BatchJob ##{batch_job.id} (#{batch_job.batch_id})"
      puts "  Status: #{status[:status]}"
      puts "  Progress: #{batch_job.completed_items}/#{batch_job.total_items} items"
      puts "  Duration: #{batch_job.duration_in_words || 'just started'}"
      
      if batch_job.estimated_completion_time
        puts "  ETA: #{batch_job.estimated_completion_time.strftime('%I:%M %p')}"
      end
      puts
    end
  end
  
  desc "Manually process a completed batch"
  task :process_batch, [:batch_id] => :environment do |_, args|
    batch_id = args[:batch_id]
    
    unless batch_id
      puts "Usage: rails entity_extraction:process_batch[batch_id]"
      exit
    end
    
    service = Search::BatchBasicEntityExtractionService.new
    puts "Processing batch #{batch_id}..."
    
    success = service.process_batch_results(batch_id)
    
    if success
      puts "✅ Batch processed successfully!"
    else
      puts "❌ Failed to process batch"
    end
  end
  
  desc "Show entity extraction statistics"
  task stats: :environment do
    puts "📊 Entity Extraction Statistics"
    puts "=" * 60
    
    # Basic entity types
    basic_types = %w[location activity theme time person item_type 
                     contact organizational service schedule requirement]
    
    puts "\nBasic Entity Counts:"
    basic_types.each do |entity_type|
      count = SearchEntity.where(entity_type: entity_type).count
      puts "  #{entity_type.ljust(20)} #{count.to_s.rjust(10)}"
    end
    
    # Items with entities
    items_with_basic = SearchableItem.joins(:search_entities)
      .where(search_entities: { entity_type: basic_types })
      .distinct.count
    
    items_with_pool = SearchableItem.joins(:search_entities)
      .where(search_entities: { entity_type: SearchEntity.where("entity_type LIKE 'pool_%'").distinct.pluck(:entity_type) })
      .distinct.count
    
    puts "\n\nItem Coverage:"
    puts "  Items with basic entities:  #{items_with_basic.to_s.rjust(10)}"
    puts "  Items with pool entities:   #{items_with_pool.to_s.rjust(10)}"
    puts "  Total searchable items:     #{SearchableItem.count.to_s.rjust(10)}"
    
    # Recent batches
    recent_batches = BatchJob.where(job_type: 'entity_extraction').recent.limit(5)
    
    if recent_batches.any?
      puts "\n\nRecent Entity Extraction Batches:"
      recent_batches.each do |batch|
        puts "  BatchJob ##{batch.id} - #{batch.status} - #{batch.total_items} items - #{batch.created_at.strftime('%m/%d %I:%M %p')}"
      end
    end
  end
end