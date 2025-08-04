namespace :search do
  desc "Check batch extraction status"
  task :batch_status, [:batch_id] => :environment do |t, args|
    batch_id = args[:batch_id]
    
    unless batch_id
      puts "❌ Please provide a batch ID"
      puts "Usage: rails search:batch_status[batch_id]"
      exit
    end
    
    service = Search::BatchPoolEntityExtractionService.new
    status = service.check_batch_status(batch_id)
    
    puts "📊 Batch Status for #{batch_id}"
    puts "=" * 60
    puts "Status: #{status[:status]}"
    puts "Created: #{status[:created_at]}"
    puts "Completed: #{status[:completed_at] || 'Not yet'}"
    
    if status[:request_counts]
      puts "\nRequest Counts:"
      status[:request_counts].each do |key, value|
        puts "  #{key}: #{value}"
      end
    end
    
    if status[:usage]
      puts "\n💰 Token Usage & Cost:"
      puts "  Input tokens: #{status[:usage][:input_tokens].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
      puts "  Output tokens: #{status[:usage][:output_tokens].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
      puts "  Total tokens: #{status[:usage][:total_tokens].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
      if status[:usage][:estimated_cost]
        puts "  Input cost: #{status[:usage][:estimated_cost][:input_cost]}"
        puts "  Output cost: #{status[:usage][:estimated_cost][:output_cost]}"
        puts "  Total cost: #{status[:usage][:estimated_cost][:total_cost]}"
        puts "  Per item: #{status[:usage][:estimated_cost][:cost_per_item]}" if status[:usage][:estimated_cost][:cost_per_item]
      end
    end
    
    if status[:errors] && status[:errors].any?
      puts "\n❌ Errors:"
      status[:errors].each { |error| puts "  - #{error}" }
    end
    
    if status[:status] == 'completed'
      puts "\n✅ Batch completed! To process results, run:"
      puts "  rails search:process_batch_results[#{batch_id}]"
    end
  end
  
  desc "Process batch extraction results"
  task :process_batch_results, [:batch_id] => :environment do |t, args|
    batch_id = args[:batch_id]
    
    unless batch_id
      puts "❌ Please provide a batch ID"
      exit
    end
    
    puts "🔄 Processing batch results for #{batch_id}..."
    
    service = Search::BatchPoolEntityExtractionService.new
    success = service.process_batch_results(batch_id)
    
    if success
      puts "\n✅ Batch results processed successfully!"
      
      # Show summary of new pool entities
      puts "\n📊 New Pool Entities Summary:"
      pool_types = %w[pool_idea pool_manifest pool_experience pool_relational 
                      pool_evolutionary pool_practical pool_emanation]
      
      pool_types.each do |pool_type|
        count = SearchEntity.where(entity_type: pool_type).count
        puts "  #{pool_type}: #{count} total entities"
      end
    else
      puts "\n❌ Failed to process batch results"
    end
  end
  desc "Extract pool entities from enliterated content"
  task extract_pool_entities: :environment do
    puts "🌊 Starting Pool Entity Extraction"
    puts "=" * 60
    
    # Get items that should have pool entities
    enliterated_types = ['philosophical_text', 'experience_story', 'practical_guide']
    items = SearchableItem.where(item_type: enliterated_types)
    
    puts "📊 Found #{items.count} enliterated items to process"
    
    # Show breakdown by type
    items.group(:item_type).count.each do |type, count|
      puts "  - #{type}: #{count} items"
    end
    
    service = Search::PoolEntityExtractionService.new
    extracted_count = 0
    error_count = 0
    
    items.find_each.with_index do |item, index|
      print "\r⏳ Processing: #{index + 1}/#{items.count} - #{item.name.truncate(50)}"
      
      begin
        # Extract pool entities
        entities = service.extract_pool_entities(item.searchable_text, item.item_type)
        
        # Save entities
        entities.each do |entity|
          SearchEntity.find_or_create_by(
            searchable_item: item,
            entity_type: entity[:type],
            entity_value: entity[:value]
          )
        end
        
        extracted_count += entities.count
      rescue => e
        error_count += 1
        puts "\n❌ Error processing #{item.name}: #{e.message}"
      end
    end
    
    puts "\n\n✅ Pool Entity Extraction Complete!"
    puts "  Total entities extracted: #{extracted_count}"
    puts "  Items processed: #{items.count}"
    puts "  Errors: #{error_count}"
    
    # Show summary
    puts "\n📊 Pool Entity Summary:"
    pool_types = %w[pool_idea pool_manifest pool_experience pool_relational 
                    pool_evolutionary pool_practical pool_emanation]
    
    pool_types.each do |pool_type|
      count = SearchEntity.where(entity_type: pool_type).count
      puts "  #{pool_type}: #{count} entities"
    end
  end
  
  desc "Extract pool entities using batch API for cost savings"
  task batch_extract_pool_entities: :environment do
    puts "🌊 Starting Batch Pool Entity Extraction"
    puts "=" * 60
    
    # Get items that need pool entities
    enliterated_types = ['philosophical_text', 'experience_story', 'practical_guide']
    
    # Check for items without pool entities
    items_needing_extraction = SearchableItem
      .where(item_type: enliterated_types)
      .includes(:search_entities)
      .select do |item|
        item.search_entities.none? { |e| e.entity_type.start_with?('pool_') }
      end
    
    if items_needing_extraction.empty?
      puts "✅ All enliterated items already have pool entities!"
      return
    end
    
    puts "📊 Found #{items_needing_extraction.count} items needing pool entity extraction"
    
    # Create batch extraction service
    batch_service = Search::BatchPoolEntityExtractionService.new
    
    # Submit batch job
    batch_id = batch_service.submit_batch_extraction(items_needing_extraction)
    
    if batch_id
      puts "\n✅ Batch job submitted successfully!"
      puts "  Batch ID: #{batch_id}"
      puts "  Items in batch: #{items_needing_extraction.count}"
      puts "\n📝 To check status, run: rails search:batch_status[#{batch_id}]"
    else
      puts "\n❌ Failed to submit batch job"
    end
  end
end