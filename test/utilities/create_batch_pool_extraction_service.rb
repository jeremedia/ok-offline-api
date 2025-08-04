#!/usr/bin/env ruby
# Create the BatchPoolEntityExtractionService

content = <<'RUBY'
module Search
  class BatchPoolEntityExtractionService
    BATCH_SIZE = 500 # OpenAI recommends max 500 per batch
    
    def initialize
      @client = OpenAI::Client.new(
        api_key: ENV.fetch('OPENAI_API_KEY'),
        timeout: 240
      )
    end
    
    def submit_batch_extraction(items)
      puts "📦 Preparing batch pool entity extraction for #{items.count} items"
      
      # Split into smaller batches if needed
      batches = items.in_groups_of(BATCH_SIZE, false)
      batch_ids = []
      
      batches.each_with_index do |batch_items, batch_index|
        puts "\n📋 Processing batch #{batch_index + 1}/#{batches.count} (#{batch_items.count} items)"
        
        # Create JSONL file
        batch_file = create_batch_file(batch_items, batch_index)
        
        # Upload to OpenAI
        file_id = upload_batch_file(batch_file)
        next unless file_id
        
        # Create batch job
        batch_id = create_batch_job(file_id)
        batch_ids << batch_id if batch_id
      end
      
      puts "\n✅ Submitted #{batch_ids.count} batch jobs"
      batch_ids
    end
    
    def check_batch_status(batch_id)
      response = @client.batches.retrieve(id: batch_id)
      
      status = {
        id: response['id'],
        status: response['status'],
        created_at: Time.at(response['created_at']),
        completed_at: response['completed_at'] ? Time.at(response['completed_at']) : nil,
        request_counts: response['request_counts'],
        errors: response['errors']
      }
      
      # If completed, return output file info
      if response['status'] == 'completed' && response['output_file_id']
        status[:output_file_id] = response['output_file_id']
      end
      
      status
    end
    
    def process_batch_results(batch_id)
      status = check_batch_status(batch_id)
      
      unless status[:status] == 'completed'
        puts "❌ Batch #{batch_id} not yet completed. Status: #{status[:status]}"
        return false
      end
      
      unless status[:output_file_id]
        puts "❌ No output file for batch #{batch_id}"
        return false
      end
      
      # Download results
      results_content = download_batch_results(status[:output_file_id])
      return false unless results_content
      
      # Process each result
      processed_count = 0
      error_count = 0
      
      results_content.each_line do |line|
        next if line.strip.empty?
        
        begin
          result = JSON.parse(line)
          process_single_result(result)
          processed_count += 1
        rescue => e
          error_count += 1
          Rails.logger.error "Error processing batch result: #{e.message}"
        end
      end
      
      puts "✅ Processed #{processed_count} results (#{error_count} errors)"
      true
    end
    
    private
    
    def create_batch_file(items, batch_index)
      timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
      filename = Rails.root.join('tmp', "pool_extraction_batch_#{timestamp}_#{batch_index}.jsonl")
      
      File.open(filename, 'w') do |file|
        items.each do |item|
          request = build_extraction_request(item)
          file.puts(request.to_json)
        end
      end
      
      puts "  📄 Created batch file: #{filename} (#{File.size(filename) / 1024}KB)"
      filename
    end
    
    def build_extraction_request(item)
      system_prompt = build_pool_extraction_prompt(item.item_type)
      
      {
        custom_id: "pool_extract_#{item.id}",
        method: "POST",
        url: "/v1/chat/completions",
        body: {
          model: Search::PoolEntityExtractionService::EXTRACTION_MODEL,
          messages: [
            { role: "system", content: system_prompt },
            { role: "user", content: item.searchable_text }
          ],
          response_format: { type: "json_object" },
          temperature: 0.3
        }
      }
    end
    
    def build_pool_extraction_prompt(item_type)
      # Reuse the prompt from PoolEntityExtractionService
      service = Search::PoolEntityExtractionService.new
      service.send(:build_pool_extraction_prompt, item_type)
    end
    
    def upload_batch_file(filepath)
      puts "  📤 Uploading to OpenAI..."
      
      begin
        response = @client.files.upload(
          parameters: {
            file: filepath,
            purpose: 'batch'
          }
        )
        
        file_id = response['id']
        puts "  ✅ Uploaded with file ID: #{file_id}"
        file_id
      rescue => e
        puts "  ❌ Upload failed: #{e.message}"
        nil
      ensure
        # Clean up local file
        File.delete(filepath) if File.exist?(filepath)
      end
    end
    
    def create_batch_job(file_id)
      puts "  🚀 Creating batch job..."
      
      begin
        response = @client.batches.create(
          parameters: {
            input_file_id: file_id,
            endpoint: "/v1/chat/completions",
            completion_window: "24h"
          }
        )
        
        batch_id = response['id']
        puts "  ✅ Batch job created: #{batch_id}"
        batch_id
      rescue => e
        puts "  ❌ Batch creation failed: #{e.message}"
        nil
      end
    end
    
    def download_batch_results(output_file_id)
      puts "📥 Downloading batch results..."
      
      begin
        response = @client.files.content(id: output_file_id)
        puts "  ✅ Downloaded results"
        response
      rescue => e
        puts "  ❌ Download failed: #{e.message}"
        nil
      end
    end
    
    def process_single_result(result)
      # Extract item ID from custom_id
      item_id = result['custom_id'].gsub('pool_extract_', '').to_i
      item = SearchableItem.find(item_id)
      
      # Parse the response
      response_body = result.dig('response', 'body')
      return unless response_body
      
      content = response_body.dig('choices', 0, 'message', 'content')
      return unless content
      
      pool_data = JSON.parse(content)
      
      # Save pool entities
      Search::PoolEntityExtractionService::POOLS.keys.each do |pool|
        pool_key = "pool_#{pool}"
        next unless pool_data[pool_key].is_a?(Array)
        
        pool_data[pool_key].each do |value|
          next if value.to_s.strip.empty?
          
          SearchEntity.find_or_create_by(
            searchable_item: item,
            entity_type: pool_key,
            entity_value: value.to_s.strip.downcase
          )
        end
      end
    end
  end
end
RUBY

File.write('app/services/search/batch_pool_entity_extraction_service.rb', content)
puts "✅ Created BatchPoolEntityExtractionService"