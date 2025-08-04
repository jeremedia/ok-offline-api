module Search
  class BatchEmbeddingService
    BATCH_SIZE = 100 # OpenAI recommends batches of 100-1000
    
    def initialize
      @client = OpenAI::Client.new(
        api_key: ENV['OPENAI_API_KEY'],
        timeout: 240
      )
    end
    
    def generate_embeddings_for_items(items)
      return if items.empty?
      
      Rails.logger.info "Generating embeddings for #{items.count} items in batches"
      
      # Process in batches
      items.in_batches(of: BATCH_SIZE) do |batch|
        process_batch(batch)
      end
    end
    
    def queue_batch_job(items, description: "Embedding generation")
      # For OpenAI Batch API, we need to create a JSONL file with requests
      local_batch_id = SecureRandom.hex(8)
      batch_file_path = Rails.root.join('tmp', "batch_#{local_batch_id}.jsonl")
      
      Rails.logger.info "Creating batch job for #{items.count} items"
      
      # Create JSONL file with embedding requests
      File.open(batch_file_path, 'w') do |file|
        items.each do |item|
          request = {
            custom_id: "item_#{item.id}",
            method: "POST",
            url: "/v1/embeddings",
            body: {
              model: "text-embedding-3-small",
              input: item.searchable_text,
              dimensions: 1536
            }
          }
          file.puts request.to_json
        end
      end
      
      # Upload file to OpenAI
      Rails.logger.info "Uploading batch file..."
      file_response = @client.files.upload(
        parameters: {
          file: File.open(batch_file_path, 'rb'),
          purpose: "batch"
        }
      )
      
      # Create batch job with metadata
      Rails.logger.info "Creating batch job..."
      batch_response = @client.batches.create(
        parameters: {
          input_file_id: file_response['id'],
          endpoint: "/v1/embeddings",
          completion_window: "24h",
          metadata: {
            description: description,
            created_by: "ok_offline_api",
            item_count: items.count.to_s,
            local_batch_id: local_batch_id
          }
        }
      )
      
      openai_batch_id = batch_response['id']
      
      # Store batch info with webhook support
      batch_info = {
        openai_batch_id: openai_batch_id,
        local_batch_id: local_batch_id,
        item_ids: items.pluck(:id),
        item_count: items.count,
        status: 'submitted',
        created_at: Time.current,
        description: description,
        webhook_ready: true
      }
      
      Rails.cache.write("batch_#{local_batch_id}", batch_info, expires_in: 48.hours)
      Rails.cache.write("batch_openai_#{openai_batch_id}", batch_info, expires_in: 48.hours)
      
      Rails.logger.info "✅ Created batch job:"
      Rails.logger.info "   OpenAI Batch ID: #{openai_batch_id}"
      Rails.logger.info "   Local Batch ID: #{local_batch_id}"
      Rails.logger.info "   Items: #{items.count}"
      Rails.logger.info "   File ID: #{file_response['id']}"
      
      # Clean up temp file
      File.delete(batch_file_path) if File.exist?(batch_file_path)
      
      {
        openai_batch_id: openai_batch_id,
        local_batch_id: local_batch_id,
        item_count: items.count
      }
    end
    
    def check_batch_status(batch_id)
      response = @client.batches.retrieve(id: batch_id)
      
      if response['status'] == 'completed'
        process_batch_results(batch_id, response['output_file_id'])
      else
        Rails.logger.info "Batch #{batch_id} status: #{response['status']}"
        response['status']
      end
    end
    
    private
    
    def process_batch(batch)
      texts = batch.map(&:searchable_text)
      
      begin
        # For immediate processing (non-batch API)
        # This is more expensive but immediate
        response = @client.embeddings(
          parameters: {
            model: 'text-embedding-3-small',
            input: texts,
            dimensions: 1536
          }
        )
        
        # Update items with embeddings
        batch.each_with_index do |item, index|
          embedding = response.dig('data', index, 'embedding')
          if embedding
            item.update_column(:embedding, embedding)
          end
        end
        
        Rails.logger.info "Generated embeddings for batch of #{batch.count} items"
      rescue => e
        Rails.logger.error "Error generating embeddings: #{e.message}"
      end
    end
    
    def process_batch_results(batch_id, output_file_id)
      # Download results file
      file_content = @client.files.content(id: output_file_id)
      
      # Get cached batch info
      batch_info = Rails.cache.read("batch_#{batch_id}")
      return unless batch_info
      
      # Parse results and update items
      file_content.each_line do |line|
        result = JSON.parse(line)
        next unless result['response']['status_code'] == 200
        
        custom_id = result['custom_id']
        item_id = custom_id.split('_').last.to_i
        embedding = result['response']['body']['data'][0]['embedding']
        
        SearchableItem.where(id: item_id).update_all(embedding: embedding)
      end
      
      # Update cache status
      batch_info[:status] = 'completed'
      Rails.cache.write("batch_#{batch_id}", batch_info, expires_in: 48.hours)
      
      Rails.logger.info "Processed batch results for #{batch_info[:item_ids].count} items"
    end
  end
end