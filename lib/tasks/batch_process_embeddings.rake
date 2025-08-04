namespace :embeddings do
  desc "Process completed OpenAI batch embeddings efficiently"
  task :process_batch, [:batch_id] => :environment do |t, args|
    batch_id = args[:batch_id] || 'batch_688beda27b34819082864054e38bf33e'
    
    puts "🚀 Processing Embeddings Batch: #{batch_id}"
    puts "=" * 60
    
    # Initial status
    initial_without = SearchableItem.where(embedding: nil).count
    initial_with = SearchableItem.where.not(embedding: nil).count
    
    puts "📊 Initial Status:"
    puts "   Items with embeddings: #{initial_with}"
    puts "   Items without embeddings: #{initial_without}"
    puts ""
    
    client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
    
    begin
      # Check batch status
      puts "🔍 Fetching batch details..."
      batch = client.batches.retrieve(id: batch_id)
      
      unless batch['status'] == 'completed'
        puts "❌ Batch not completed. Status: #{batch['status']}"
        exit 1
      end
      
      puts "   Total requests: #{batch['request_counts']['total']}"
      puts "   Completed: #{batch['request_counts']['completed']}"
      puts "   Failed: #{batch['request_counts']['failed']}"
      puts ""
      
      # Download results
      puts "📥 Downloading results (this may take ~1 minute)..."
      start_time = Time.now
      file_content = client.files.content(id: batch['output_file_id'])
      download_time = Time.now - start_time
      puts "   Download completed in #{download_time.round(1)} seconds"
      
      unless file_content.is_a?(Array)
        puts "❌ Unexpected file format: #{file_content.class}"
        exit 1
      end
      
      puts "   Total results: #{file_content.length}"
      puts ""
      
      # Process in chunks with progress updates
      puts "🔄 Processing embeddings..."
      results_processed = 0
      errors_found = 0
      chunk_size = 500
      total_chunks = (file_content.length / chunk_size.to_f).ceil
      
      file_content.each_slice(chunk_size).with_index do |chunk, chunk_index|
        chunk_start = Time.now
        
        # Process chunk
        chunk.each do |result|
          if result['response'] && result['response']['status_code'] == 200
            custom_id = result['custom_id']
            item_id = custom_id.split('_').last.to_i
            embedding = result['response']['body']['data'][0]['embedding']
            
            if SearchableItem.where(id: item_id).update_all(embedding: embedding) > 0
              results_processed += 1
            end
          else
            errors_found += 1
          end
        end
        
        # Progress update
        chunk_time = Time.now - chunk_start
        progress = ((chunk_index + 1).to_f / total_chunks * 100).round(1)
        items_done = [results_processed + errors_found, file_content.length].min
        
        puts "   Chunk #{chunk_index + 1}/#{total_chunks} (#{progress}%) - #{items_done}/#{file_content.length} items - #{chunk_time.round(1)}s"
        
        # Estimate remaining time
        if chunk_index > 0
          avg_chunk_time = (Time.now - start_time) / (chunk_index + 1)
          remaining_chunks = total_chunks - chunk_index - 1
          eta_seconds = avg_chunk_time * remaining_chunks
          eta_minutes = (eta_seconds / 60).round(1)
          puts "   ETA: ~#{eta_minutes} minutes remaining"
        end
      end
      
      puts ""
      puts "✅ Processing complete!"
      puts "   Embeddings processed: #{results_processed}"
      puts "   Errors: #{errors_found}"
      puts "   Total time: #{((Time.now - start_time) / 60).round(1)} minutes"
      
      # Final status
      final_without = SearchableItem.where(embedding: nil).count
      final_with = SearchableItem.where.not(embedding: nil).count
      
      puts ""
      puts "📊 Final Status:"
      puts "   Items with embeddings: #{final_with} (added #{final_with - initial_with})"
      puts "   Items without embeddings: #{final_without}"
      puts "   Success rate: #{(results_processed.to_f / file_content.length * 100).round(1)}%"
      
    rescue => e
      puts "❌ Error: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      exit 1
    end
  end
  
  desc "Check embedding status"
  task status: :environment do
    total = SearchableItem.count
    with_embeddings = SearchableItem.where.not(embedding: nil).count
    without_embeddings = SearchableItem.where(embedding: nil).count
    
    by_type = SearchableItem.group(:item_type)
                           .pluck(:item_type, 
                                  Arel.sql('COUNT(*)'), 
                                  Arel.sql('COUNT(CASE WHEN embedding IS NOT NULL THEN 1 END)'))
    
    puts "📊 Embedding Status:"
    puts "   Total items: #{total}"
    puts "   With embeddings: #{with_embeddings} (#{(with_embeddings.to_f / total * 100).round(1)}%)"
    puts "   Without embeddings: #{without_embeddings}"
    puts ""
    puts "By type:"
    by_type.each do |type, total_count, with_count|
      percentage = (with_count.to_f / total_count * 100).round(1)
      puts "   #{type}: #{with_count}/#{total_count} (#{percentage}%)"
    end
  end
end