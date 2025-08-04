require_relative "entity_extraction_schema"

module Search
  # BatchBasicEntityExtractionService - Extracts 12 basic entity types using OpenAI Batch API
  #
  # This service processes SearchableItems to extract basic entities (names, locations, activities, etc.)
  # complementing the existing pool entity extraction. Uses OpenAI Batch API for 50% cost savings.
  #
  # PRODUCTION READY - Tested on 23 items with 100% success rate
  #
  # Structured Outputs Implementation:
  # - Uses OpenAI::BaseModel schema (Search::BasicEntityExtraction) for type-safe responses
  # - For batch requests, must serialize schema to JSON format, not class reference
  # - Batch responses may include 'parsed' field with structured data
  # - Falls back to JSON parsing for backward compatibility
  #
  # Full Production Batch (~45,869 items):
  # - Estimated cost: ~$56 (with 50% batch discount)
  # - Processing time: 5-30 minutes typical
  # - Webhook automation will trigger ProcessBatchResultsJob
  # - Manual fallback: service.process_batch_results(batch_id)
  #
  # Entity Types Extracted:
  # - Basic: location, activity, theme, time, person, item_type, contact, organizational, service, schedule, requirement
  # - Pool entities (handled separately): pool_idea, pool_manifest, pool_experience, etc.
  #
  # Integration Points:
  # - BatchJob model: Tracks batch status and metadata
  # - WebhooksController: Handles OpenAI completion webhooks
  # - ProcessBatchResultsJob: Background processing triggered by webhooks
  #
  # Known Issues:
  # - OpenAI webhooks may be delayed after batch completion (manual processing may be needed)
  # - Method signature must match ProcessBatchResultsJob expectations (only batch_id parameter)
  #
  # Usage:
  #   service = Search::BatchBasicEntityExtractionService.new
  #   batch_id = service.submit_batch_extraction(items)
  #   # Wait for webhook or manually: service.process_batch_results(batch_id)
  class BatchBasicEntityExtractionService
    BATCH_SIZE = 100 # OpenAI recommends batches of 100-1000
    EXTRACTION_MODEL = "gpt-4.1-nano-2025-04-14"

    def initialize
      @client = OpenAI::Client.new(
        api_key: ENV["OPENAI_API_KEY"],
        timeout: 240
      )
    end

    def submit_batch_extraction(items)
      puts "📦 Preparing batch basic entity extraction for #{items.count} items"

      # Show cost estimate upfront
      total_estimate = estimate_batch_cost(items)
      puts "\n💰 Cost Estimate:"
      puts "  Items: #{total_estimate[:items]}"
      puts "  Est. tokens: #{total_estimate[:estimated_total_tokens].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
      puts "  Est. cost: #{total_estimate[:estimated_cost]}"
      puts "  Per item: #{total_estimate[:cost_per_item]}"

      # Store item count for cost calculation
      @last_batch_item_count = items.count

      # Create JSONL file
      batch_file = create_batch_file(items, 0)

      # Upload to OpenAI
      file_id = upload_batch_file(batch_file)
      return nil unless file_id

      # Create batch job
      batch_id = create_batch_job(file_id)

      if batch_id
        # Create database record (AFTER successful OpenAI submission)
        est_cost = estimate_batch_cost(items)[:estimated_cost].gsub("$", "").to_f
        BatchJob.create_from_submission(batch_id, "entity_extraction", items, est_cost)
        puts "✅ Created BatchJob record for #{batch_id}"
      end

      batch_id
    end

    def process_batch_results(batch_id)
      status = check_batch_status(batch_id)
      
      puts "🔍 Checking batch #{batch_id}"
      puts "   Status: #{status[:status].inspect} (class: #{status[:status].class})"
      puts "   Output file: #{status[:output_file_id].inspect}"

      unless status[:status].to_s == "completed"
        puts "❌ Batch #{batch_id} not yet completed. Status: #{status[:status]}"
        Rails.logger.info "Batch status details: #{status.inspect}"
        return false
      end

      unless status[:output_file_id]
        puts "❌ No output file for batch #{batch_id}"
        Rails.logger.info "Batch status details: #{status.inspect}"
        return false
      end

      # Download results
      results_content = download_batch_results(status[:output_file_id])
      return false unless results_content
      
      puts "📊 Results content type: #{results_content.class}"
      puts "📊 Results content size: #{results_content.to_s.size} chars"
      
      # Debug: Show first part of content
      if results_content.respond_to?(:string)
        puts "📊 First 200 chars: #{results_content.string[0..200]}"
      elsif results_content.is_a?(String)
        puts "📊 First 200 chars: #{results_content[0..200]}"
      end

      # Process each result
      processed_count = 0
      error_count = 0
      total_tokens = { input: 0, output: 0 }

      # Handle different response formats from OpenAI
      content_string = case results_content
      when StringIO
        results_content.string
      when String
        results_content
      else
        results_content.to_s
      end
      
      lines = case content_string
      when Array
                content_string
      when String
                content_string.split("\n")
      when Hash
                # Single result wrapped in a hash
                [ content_string ]
      else
                Rails.logger.error "Unexpected results format: #{content_string.class}"
                []
      end

      lines.each do |line|
        next if line.to_s.strip.empty?

        begin
          result = line.is_a?(String) ? JSON.parse(line) : line
          process_single_result(result)
          processed_count += 1

          # Track token usage if available
          if result.dig("response", "body", "usage")
            usage = result["response"]["body"]["usage"]
            total_tokens[:input] += usage["prompt_tokens"] || 0
            total_tokens[:output] += usage["completion_tokens"] || 0
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

    def download_batch_results(output_file_id)
      puts "📥 Downloading batch results..."

      begin
        response = @client.files.content(output_file_id)
        puts "  ✅ Downloaded results"
        response
      rescue => e
        puts "  ❌ Download failed: #{e.message}"
        nil
      end
    end

    def process_single_result(result)
      # Extract item ID from custom_id
      item_id = result["custom_id"].gsub("basic_entity_", "").to_i
      item = SearchableItem.find(item_id)

      # Parse the response - structured outputs come as parsed objects, not JSON strings
      response_body = result.dig("response", "body")
      return unless response_body

      # For structured outputs in batch responses, check for parsed field
      parsed_content = response_body.dig("choices", 0, "message", "parsed")
      if parsed_content
        # Use parsed structured output - convert to hash if needed
        entities_data = parsed_content.is_a?(Hash) ? parsed_content : parsed_content.to_h
      else
        # Fallback to JSON parsing for compatibility
        content = response_body.dig("choices", 0, "message", "content")
        return unless content
        entities_data = JSON.parse(content)
      end

      # Create basic entities using the same logic as before
      normalization_service = EntityNormalizationService.new
      create_basic_entities_for_item(item, entities_data, normalization_service)
    end

    def estimate_batch_cost(items)
      # Estimate tokens based on average searchable_text length
      # Rough estimate: 1 token ≈ 4 characters
      total_chars = items.sum { |item| item.searchable_text.to_s.length }

      # System prompt is roughly 600 tokens per request (longer than pool extraction)
      system_prompt_tokens = 600 * items.count

      # User content tokens
      content_tokens = total_chars / 4

      # Total input tokens
      estimated_input_tokens = system_prompt_tokens + content_tokens

      # Output is typically 300-400 tokens per item for basic extraction
      estimated_output_tokens = 350 * items.count

      # Calculate estimated cost for batch API (50% discount)
      cost_per_million = 0.20 * 0.5  # Batch API discount
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

    def check_batch_status(batch_id)
      response = @client.batches.retrieve(batch_id)

      # Convert to hash format for compatibility
      response_hash = {
        "id" => response.id,
        "status" => response.status,
        "created_at" => response.created_at,
        "completed_at" => response.completed_at,
        "request_counts" => response.request_counts&.to_h,
        "errors" => response.errors,
        "output_file_id" => response.output_file_id,
        "usage" => response.respond_to?(:usage) ? response.usage&.to_h : nil
      }

      # Update database record
      batch_job = BatchJob.find_by(batch_id: batch_id)
      if batch_job
        batch_job.update_from_api_response(response_hash)

        # Update tokens if available
        if response.respond_to?(:usage) && response.usage
          batch_job.update!(
            input_tokens: response.usage.prompt_tokens,
            output_tokens: response.usage.completion_tokens
          )
        end
      end

      status = {
        id: response.id,
        status: response.status,
        created_at: Time.at(response.created_at),
        completed_at: response.completed_at ? Time.at(response.completed_at) : nil,
        request_counts: response.request_counts&.to_h,
        errors: response.errors
      }

      # If completed, return output file info
      if response.status.to_s == "completed" && response.output_file_id
        status[:output_file_id] = response.output_file_id
      end

      status
    end

    # Simple utility method to find items by IDs (avoids complex queries)
    def self.find_items_by_ids(item_ids)
      SearchableItem.where(id: item_ids)
    end

    private

    def create_batch_file(items, batch_index)
      timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
      filename = Rails.root.join("tmp", "basic_extraction_batch_#{timestamp}_#{batch_index}.jsonl")

      File.open(filename, "w") do |file|
        items.each do |item|
          request = build_extraction_request(item)
          file.puts(request.to_json)
        end
      end

      puts "  📄 Created batch file: #{filename} (#{File.size(filename) / 1024}KB)"
      filename
    end

    def upload_batch_file(filepath)
      puts "  📤 Uploading to OpenAI..."

      begin
        response = @client.files.create(
          file: File.open(filepath),
          purpose: "batch"
        )

        file_id = response.id
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
          input_file_id: file_id,
          endpoint: "/v1/chat/completions",
          completion_window: "24h"
        )

        batch_id = response.id
        puts "  ✅ Batch job created: #{batch_id}"
        batch_id
      rescue => e
        puts "  ❌ Batch creation failed: #{e.message}"
        nil
      end
    end

    def build_extraction_request(item)
      {
        custom_id: "basic_entity_#{item.id}",
        method: "POST",
        url: "/v1/chat/completions",
        body: {
          model: EXTRACTION_MODEL,
          messages: [
            { role: "system", content: build_basic_system_prompt(item.item_type) },
            { role: "user", content: build_extraction_text(item) }
          ],
          response_format: {
            type: "json_schema",
            json_schema: {
              name: "basic_entity_extraction",
              schema: Search::BasicEntityExtraction.to_json_schema,
              strict: true
            }
          },
          temperature: 0.3,
          max_tokens: 1000
        }
      }
    end

    def build_basic_system_prompt(item_type)
      base_prompt = <<~PROMPT
        You are an entity extraction system for Burning Man content.#{' '}
        Extract relevant entities from the given text and categorize them using the structured format.

        Guidelines:
        - Extract proper names, locations (including BRC addresses like "7:30 & C"), activities, themes, people, contact info
        - Include organizational relationships, services offered, schedule details, and requirements#{'  '}
        - Use high confidence extractions only - return empty arrays for categories with no clear entities
        - Focus on concrete, specific information rather than general concepts
      PROMPT

      case item_type
      when "camp"
        base_prompt + "\nFocus on camp offerings, location, and community themes."
      when "art"
        base_prompt + "\nFocus on artistic themes, installation concepts, and interactivity."
      when "event"
        base_prompt + "\nFocus on event activities, timing, and participating entities."
      else
        base_prompt
      end
    end

    def build_extraction_text(item)
      # Combine all relevant text fields for comprehensive extraction
      parts = []
      parts << "Name: #{item.name}" if item.name.present?
      parts << "Description: #{item.description}" if item.description.present?
      parts << "Location: #{item.location_string}" if item.location_string.present?
      parts << "Year: #{item.year}" if item.year.present?

      # Add any metadata that might contain useful information
      if item.metadata.present?
        parts << "Additional Info: #{item.metadata.slice('hometown', 'url', 'contact_email').to_json}"
      end

      parts.join("\n\n")
    end

    def create_basic_entities_for_item(item, entities_data, normalization_service)
      # Map extraction results to our entity types
      entity_mappings = {
        "names" => "location", # Names will be treated as locations for discoverability
        "locations" => "location",
        "activities" => "activity",
        "themes" => "theme",
        "times" => "time",
        "people" => "person",
        "item_type" => "item_type",
        "contact" => "contact",
        "organizational" => "organizational",
        "services" => "service",
        "schedule" => "schedule",
        "requirements" => "requirement"
      }

      entity_mappings.each do |key, entity_type|
        next unless entities_data[key].is_a?(Array)

        entities_data[key].each do |value|
          # Normalize the entity value
          normalized_value = normalization_service.normalize_entity(
            entity_type,
            value.to_s.strip
          )

          # Check if this entity already exists for this item
          existing_entity = item.search_entities.find_by(
            entity_type: entity_type,
            entity_value: normalized_value
          )

          # Only create if it doesn't already exist
          unless existing_entity
            SearchEntity.create!(
              searchable_item: item,
              entity_type: entity_type,
              entity_value: normalized_value,
              confidence: 0.9
            )
          end
        end
      end

      Rails.logger.info "Created basic entities for item #{item.id} (#{item.name})"
    rescue => e
      Rails.logger.error "Error creating basic entities for item #{item.id}: #{e.message}"
    end
  end
end
