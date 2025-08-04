class BatchCompletionJob < ApplicationJob
  queue_as :default
  
  def perform(batch_id)
    Rails.logger.info "Processing batch completion: #{batch_id}"
    
    client = OpenAI::Client.new(api_key: ENV['OPENAI_API_KEY'])
    
    begin
      # Get batch details
      batch = client.batches.retrieve(id: batch_id)
      
      unless batch['status'] == 'completed'
        Rails.logger.warn "Batch #{batch_id} status is #{batch['status']}, not completed"
        return
      end
      
      output_file_id = batch['output_file_id']
      unless output_file_id
        Rails.logger.error "No output file for batch #{batch_id}"
        return
      end
      
      Rails.logger.info "Downloading results from file: #{output_file_id}"
      
      # Check batch info to determine task type
      batch_info = Rails.cache.read("batch_openai_#{batch_id}")
      task_type = batch_info&.dig(:task_type) || 'embeddings'
      
      Rails.logger.info "Processing batch for task type: #{task_type}"
      
      # Download and process results
      file_content = client.files.content(id: output_file_id)
      
      # Route to appropriate processor
      if task_type == 'entity_extraction'
        process_entity_extraction_batch(batch_id, file_content)
        return
      end
      
      results_processed = 0
      errors_found = 0
      
      # Handle Hash (single result), Array (large batch), and String (JSONL) formats
      if file_content.is_a?(Hash)
        # Single result format (for small batches)
        result = file_content
        Rails.logger.info "Processing single result: #{result['custom_id']}"
        
        if result['response'] && result['response']['status_code'] == 200
          # Successful embedding
          custom_id = result['custom_id']
          item_id = custom_id.split('_').last.to_i
          
          embedding = result['response']['body']['data'][0]['embedding']
          
          # Update the SearchableItem with the embedding
          if SearchableItem.where(id: item_id).update_all(embedding: embedding) > 0
            results_processed += 1
            Rails.logger.info "✅ Updated embedding for item #{item_id}"
          else
            Rails.logger.warn "Item not found for ID: #{item_id}"
          end
        else
          # Error in processing
          errors_found += 1
          Rails.logger.error "Batch result error: #{result['error'] || 'Unknown error'}"
        end
      elsif file_content.is_a?(Array)
        # Array format (for large batches)
        Rails.logger.info "Processing array of #{file_content.length} results"
        
        file_content.each_with_index do |result, index|
          if index % 1000 == 0
            Rails.logger.info "Processing result #{index}/#{file_content.length}..."
          end
          
          if result['response'] && result['response']['status_code'] == 200
            # Successful embedding
            custom_id = result['custom_id']
            item_id = custom_id.split('_').last.to_i
            
            embedding = result['response']['body']['data'][0]['embedding']
            
            # Update the SearchableItem with the embedding
            if SearchableItem.where(id: item_id).update_all(embedding: embedding) > 0
              results_processed += 1
            else
              Rails.logger.warn "Item not found for ID: #{item_id}"
            end
          else
            # Error in processing
            errors_found += 1
            Rails.logger.error "Batch result error: #{result['error'] || 'Unknown error'}"
          end
        end
      else
        # JSONL format (String - for medium batches)
        Rails.logger.info "Processing JSONL results"
        
        file_content.each_line do |line|
          next if line.strip.empty?
          
          begin
            result = JSON.parse(line.strip)
            
            if result['response'] && result['response']['status_code'] == 200
              # Successful embedding
              custom_id = result['custom_id']
              item_id = custom_id.split('_').last.to_i
              
              embedding = result['response']['body']['data'][0]['embedding']
              
              # Update the SearchableItem with the embedding
              if SearchableItem.where(id: item_id).update_all(embedding: embedding) > 0
                results_processed += 1
              else
                Rails.logger.warn "Item not found for ID: #{item_id}"
              end
            else
              # Error in processing
              errors_found += 1
              Rails.logger.error "Batch result error: #{result['error'] || 'Unknown error'}"
            end
            
          rescue JSON::ParserError => e
            Rails.logger.error "Failed to parse batch result line: #{e.message}"
            errors_found += 1
          end
        end
      end
      
      Rails.logger.info "✅ Batch processing complete:"
      Rails.logger.info "   Embeddings processed: #{results_processed}"
      Rails.logger.info "   Errors found: #{errors_found}"
      Rails.logger.info "   Total requests: #{batch['request_counts']['total']}"
      
      # Update cache with final results
      Rails.cache.write("batch_results_#{batch_id}", {
        status: 'processed',
        processed_at: Time.current,
        results_processed: results_processed,
        errors_found: errors_found,
        total_requests: batch['request_counts']['total']
      }, expires_in: 48.hours)
      
    rescue => e
      Rails.logger.error "Failed to process batch completion: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # Store error info
      Rails.cache.write("batch_results_#{batch_id}", {
        status: 'processing_failed',
        error: e.message,
        failed_at: Time.current
      }, expires_in: 48.hours)
    end
  end
  
  private
  
  def process_entity_extraction_batch(batch_id, file_content)
    Rails.logger.info "Processing entity extraction batch"
    
    # Get batch details to find output_file_id
    client = OpenAI::Client.new(api_key: ENV['OPENAI_API_KEY'])
    batch = client.batches.retrieve(id: batch_id)
    output_file_id = batch['output_file_id']
    
    # Use the batch entity extraction service to process results
    service = Search::BatchEntityExtractionService.new
    service.process_batch_results(batch_id, output_file_id)
  end
end