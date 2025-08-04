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
      
      # Show cost estimate upfront
      total_estimate = estimate_batch_cost(items)
      puts "\n💰 Cost Estimate:"
      puts "  Items: #{total_estimate[:items]}"
      puts "  Est. tokens: #{total_estimate[:estimated_total_tokens].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
      puts "  Est. cost: #{total_estimate[:estimated_cost]}"
      puts "  Per item: #{total_estimate[:cost_per_item]}"
      
      # Split into smaller batches if needed
      batches = items.in_groups_of(BATCH_SIZE, false)
      batch_ids = []
      
      batches.each_with_index do |batch_items, batch_index|
        puts "\n📋 Processing batch #{batch_index + 1}/#{batches.count} (#{batch_items.count} items)"
        
        # Store item count for cost calculation
        @last_batch_item_count = batch_items.count
        
        # Create JSONL file
        batch_file = create_batch_file(batch_items, batch_index)
        
        # Upload to OpenAI
        file_id = upload_batch_file(batch_file)
        next unless file_id
        
        # Create batch job
        batch_id = create_batch_job(file_id)
        
        if batch_id
          batch_ids << batch_id
          
          # Create database record
          est_cost = estimate_batch_cost(batch_items)[:estimated_cost].gsub('$','').to_f
          BatchJob.create_from_submission(batch_id, 'pool_extraction', batch_items, est_cost)
        end
      end
      
      puts "\n✅ Submitted #{batch_ids.count} batch jobs"
      batch_ids
    end
    
    def check_batch_status(batch_id)
      response = @client.batches.retrieve(id: batch_id)
      
      # Update database record
      batch_job = BatchJob.find_by(batch_id: batch_id)
      if batch_job
        batch_job.update_from_api_response(response)
        
        # Update tokens if available
        if response['usage']
          batch_job.update!(
            input_tokens: response['usage']['prompt_tokens'],
            output_tokens: response['usage']['completion_tokens']
          )
        end
      end
      
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
      
      # Calculate costs for GPT-4.1-nano
      # $0.20 per 1M tokens for both input and output
      if response['usage']
        input_tokens = response['usage']['prompt_tokens'] || 0
        output_tokens = response['usage']['completion_tokens'] || 0
        
        status[:usage] = {
          input_tokens: input_tokens,
          output_tokens: output_tokens,
          total_tokens: input_tokens + output_tokens,
          estimated_cost: calculate_batch_cost(input_tokens, output_tokens)
        }
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
      total_tokens = { input: 0, output: 0 }
      
      # Handle different response formats from OpenAI
      lines = case results_content
              when Array
                results_content
              when String
                results_content.split("\n")
              when Hash
                # Single result wrapped in a hash
                [results_content]
              else
                Rails.logger.error "Unexpected results format: #{results_content.class}"
                []
              end
      
      lines.each do |line|
        next if line.to_s.strip.empty?
        
        begin
          result = line.is_a?(String) ? JSON.parse(line) : line
          process_single_result(result)
          processed_count += 1
          
          # Track token usage if available
          if result.dig('response', 'body', 'usage')
            usage = result['response']['body']['usage']
            total_tokens[:input] += usage['prompt_tokens'] || 0
            total_tokens[:output] += usage['completion_tokens'] || 0
          end
        rescue => e
          error_count += 1
          Rails.logger.error "Error processing batch result: #{e.message}"
        end
      end
      
      # Update batch job with token usage
      if batch_job = BatchJob.find_by(batch_id: batch_id)
        batch_job.update!(
          input_tokens: total_tokens[:input],
          output_tokens: total_tokens[:output]
        ) if total_tokens[:input] > 0
      end
      
      puts "✅ Processed #{processed_count} results (#{error_count} errors)"
      true
    end
    
    def estimate_batch_cost(items)
      # Estimate tokens based on average searchable_text length
      # Rough estimate: 1 token ≈ 4 characters
      total_chars = items.sum { |item| item.searchable_text.to_s.length }
      
      # System prompt is roughly 500 tokens per request
      system_prompt_tokens = 500 * items.count
      
      # User content tokens
      content_tokens = total_chars / 4
      
      # Total input tokens
      estimated_input_tokens = system_prompt_tokens + content_tokens
      
      # Output is typically 200-400 tokens per item for pool extraction
      estimated_output_tokens = 300 * items.count
      
      # Calculate estimated cost
      cost_per_million = 0.20
      estimated_cost = ((estimated_input_tokens + estimated_output_tokens) / 1_000_000.0) * cost_per_million
      
      {
        items: items.count,
        estimated_input_tokens: estimated_input_tokens,
        estimated_output_tokens: estimated_output_tokens,
        estimated_total_tokens: estimated_input_tokens + estimated_output_tokens,
        estimated_cost: "$#{'%.4f' % estimated_cost}",
        cost_per_item: "$#{'%.6f' % (estimated_cost / items.count)}"
      }
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
            file: File.open(filepath),
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
    
    def calculate_batch_cost(input_tokens, output_tokens)
      # GPT-4.1-nano pricing: $0.20 per 1M tokens for both input and output
      cost_per_million = 0.20
      
      input_cost = (input_tokens / 1_000_000.0) * cost_per_million
      output_cost = (output_tokens / 1_000_000.0) * cost_per_million
      total_cost = input_cost + output_cost
      
      result = {
        input_cost: "$#{'%.4f' % input_cost}",
        output_cost: "$#{'%.4f' % output_cost}",
        total_cost: "$#{'%.4f' % total_cost}"
      }
      
      if @last_batch_item_count && @last_batch_item_count > 0
        result[:cost_per_item] = "$#{'%.6f' % (total_cost / @last_batch_item_count)}"
      end
      
      result
    end
  end
end
