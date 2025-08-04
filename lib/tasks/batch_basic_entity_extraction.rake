namespace :search do
  namespace :batch do
    desc "Submit batch job for basic entity extraction on items missing basic entities"
    task :submit_basic_extraction, [:batch_size] => :environment do |task, args|
      batch_size = (args[:batch_size] || 100).to_i
      
      puts "🔍 Finding items needing basic entity extraction..."
      
      # Find items that have pool entities but no basic entities
      basic_entity_types = ['location', 'activity', 'theme', 'time', 'person', 'item_type', 
                           'contact', 'organizational', 'service', 'schedule', 'requirement']
      
      # Get IDs of items that already have basic entities
      items_with_basic_ids = SearchEntity.where(entity_type: basic_entity_types)
                                         .distinct
                                         .pluck(:searchable_item_id)
      
      # Find items that have entities but no basic entities (pool-only items)
      items_with_entities_ids = SearchEntity.distinct.pluck(:searchable_item_id)
      items_needing_basic_ids = items_with_entities_ids - items_with_basic_ids
      
      total_items = items_needing_basic_ids.count
      puts "Found #{total_items} items needing basic entity extraction"
      
      if total_items == 0
        puts "✅ No items need basic entity extraction!"
        next
      end
      
      # Estimate cost
      avg_input_tokens = 29 # From our analysis
      avg_output_tokens = 300
      total_input_tokens = avg_input_tokens * total_items
      total_output_tokens = avg_output_tokens * total_items
      
      # Batch API pricing (50% discount)
      input_cost = (total_input_tokens * 0.000002 * 0.5)
      output_cost = (total_output_tokens * 0.000008 * 0.5)
      total_cost = input_cost + output_cost
      
      puts "\n💰 Cost Estimation:"
      puts "   Input tokens: #{total_input_tokens.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
      puts "   Output tokens: #{total_output_tokens.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
      puts "   Estimated cost: $#{total_cost.round(2)}"
      
      print "\n🚀 Proceed with batch submission? (y/N): "
      confirmation = STDIN.gets.strip.downcase
      
      unless confirmation == 'y' || confirmation == 'yes'
        puts "❌ Batch submission cancelled"
        next
      end
      
      # Process in batches
      service = Search::BatchBasicEntityExtractionService.new
      batches_created = []
      
      items_needing_basic_ids.each_slice(batch_size) do |batch_item_ids|
        puts "\n📦 Processing batch of #{batch_item_ids.size} items..."
        
        # Get the actual items for this batch
        batch_items = Search::BatchBasicEntityExtractionService.find_items_by_ids(batch_item_ids)
        
        batch_info = service.queue_batch_extraction(
          batch_items,
          description: "Basic entity extraction batch (#{batch_items.size} items)"
        )
        
        batches_created << batch_info
        puts "   ✅ Created batch: #{batch_info[:local_batch_id]}"
        puts "   📊 OpenAI Batch ID: #{batch_info[:openai_batch_id]}"
        
        # Brief pause between batch submissions
        sleep(1)
      end
      
      puts "\n🎉 Successfully created #{batches_created.size} batch jobs!"
      puts "\n📋 Batch Summary:"
      batches_created.each do |batch|
        puts "   • #{batch[:local_batch_id]} (#{batch[:item_count]} items) - #{batch[:openai_batch_id]}"
      end
      
      puts "\n⏰ Batches typically complete within 24 hours"
      puts "📊 Monitor progress with: rails search:batch:status"
      puts "🔄 Process results with webhook or manual processing"
    end
    
    desc "Check status of all basic entity extraction batches"
    task :status => :environment do
      puts "📊 Checking status of basic entity extraction batches...\n"
      
      # Find all cached batch info
      cache_keys = Rails.cache.instance_variable_get(:@data).keys.select { |k| k.include?("batch_basic_entities_") }
      
      if cache_keys.empty?
        puts "No basic entity extraction batches found in cache"
        next
      end
      
      cache_keys.each do |key|
        batch_info = Rails.cache.read(key)
        next unless batch_info
        
        puts "📦 Batch: #{batch_info[:local_batch_id]}"
        puts "   OpenAI ID: #{batch_info[:openai_batch_id]}"
        puts "   Items: #{batch_info[:item_count]}"
        puts "   Status: #{batch_info[:status]}"
        puts "   Created: #{batch_info[:created_at]}"
        puts "   Processed: #{batch_info[:processed_count] || 'N/A'}"
        puts ""
      end
    end
    
    desc "Process completed batch results manually (if webhook failed)"
    task :process_results, [:batch_id] => :environment do |task, args|
      batch_id = args[:batch_id]
      
      if batch_id.blank?
        puts "❌ Please provide a batch ID: rails search:batch:process_results[batch_id]"
        next
      end
      
      puts "🔄 Processing batch results for: #{batch_id}"
      
      begin
        client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
        batch_info = client.batches.retrieve(id: batch_id)
        
        if batch_info['status'] == 'completed' && batch_info['output_file_id']
          service = Search::BatchBasicEntityExtractionService.new
          service.process_batch_results(batch_id, batch_info['output_file_id'])
          puts "✅ Successfully processed batch results"
        else
          puts "❌ Batch not ready or completed. Status: #{batch_info['status']}"
        end
      rescue => e
        puts "❌ Error processing batch: #{e.message}"
      end
    end
    
    desc "Show extraction coverage statistics"
    task :stats => :environment do
      puts "📊 Basic Entity Extraction Coverage Statistics\n"
      
      basic_entity_types = ['location', 'activity', 'theme', 'time', 'person', 'item_type', 
                           'contact', 'organizational', 'service', 'schedule', 'requirement']
      
      items_with_basic_ids = SearchEntity.where(entity_type: basic_entity_types)
                                         .distinct
                                         .pluck(:searchable_item_id)
      
      total_items = SearchableItem.count
      items_with_basic = items_with_basic_ids.count
      items_with_entities = SearchableItem.joins(:search_entities).distinct.count
      items_needing_basic = items_with_entities - items_with_basic
      items_no_entities = total_items - items_with_entities
      
      puts "📈 Coverage Overview:"
      puts "   Total items: #{total_items.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
      puts "   Items with basic entities: #{items_with_basic.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} (#{((items_with_basic.to_f / total_items) * 100).round(1)}%)"
      puts "   Items needing basic extraction: #{items_needing_basic.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} (#{((items_needing_basic.to_f / total_items) * 100).round(1)}%)"
      puts "   Items with no entities: #{items_no_entities.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} (#{((items_no_entities.to_f / total_items) * 100).round(1)}%)"
      
      puts "\n🎯 Entity Type Breakdown:"
      basic_entity_types.each do |entity_type|
        count = SearchEntity.where(entity_type: entity_type).count
        puts "   #{entity_type}: #{count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
      end
    end
  end
end