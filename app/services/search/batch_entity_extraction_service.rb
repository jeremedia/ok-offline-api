module Search
  class BatchEntityExtractionService
    BATCH_SIZE = 100 # OpenAI recommends batches of 100-1000
    EXTRACTION_MODEL = "gpt-4.1-nano-2025-04-14"
    
    def initialize
      @client = OpenAI::Client.new(
        api_key: ENV['OPENAI_API_KEY'],
        timeout: 240
      )
    end
    
    def queue_batch_extraction(items, description: "Entity extraction with seven pools awareness")
      # Create JSONL file with extraction requests
      local_batch_id = SecureRandom.hex(8)
      batch_file_path = Rails.root.join('tmp', "batch_entities_#{local_batch_id}.jsonl")
      
      Rails.logger.info "Creating batch entity extraction job for #{items.count} items"
      
      # Create JSONL file
      File.open(batch_file_path, 'w') do |file|
        items.each do |item|
          request = build_extraction_request(item)
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
      
      # Create batch job
      Rails.logger.info "Creating batch job..."
      batch_response = @client.batches.create(
        parameters: {
          input_file_id: file_response['id'],
          endpoint: "/v1/chat/completions",
          completion_window: "24h",
          metadata: {
            description: description,
            created_by: "ok_offline_api",
            item_count: items.count.to_s,
            local_batch_id: local_batch_id,
            task_type: "entity_extraction"
          }
        }
      )
      
      openai_batch_id = batch_response['id']
      
      # Store batch info for webhook processing
      batch_info = {
        openai_batch_id: openai_batch_id,
        local_batch_id: local_batch_id,
        item_ids: items.pluck(:id),
        item_count: items.count,
        status: 'submitted',
        created_at: Time.current,
        description: description,
        task_type: 'entity_extraction',
        webhook_ready: true
      }
      
      Rails.cache.write("batch_entities_#{local_batch_id}", batch_info, expires_in: 48.hours)
      Rails.cache.write("batch_openai_#{openai_batch_id}", batch_info, expires_in: 48.hours)
      
      Rails.logger.info "✅ Created entity extraction batch job:"
      Rails.logger.info "   OpenAI Batch ID: #{openai_batch_id}"
      Rails.logger.info "   Local Batch ID: #{local_batch_id}"
      Rails.logger.info "   Items: #{items.count}"
      
      # Clean up temp file
      File.delete(batch_file_path) if File.exist?(batch_file_path)
      
      {
        openai_batch_id: openai_batch_id,
        local_batch_id: local_batch_id,
        item_count: items.count
      }
    end
    
    def process_batch_results(batch_id, output_file_id)
      # Download results file
      file_content = @client.files.content(id: output_file_id)
      
      # Get cached batch info
      batch_info = Rails.cache.read("batch_openai_#{batch_id}")
      return unless batch_info
      
      normalization_service = EntityNormalizationService.new
      processed_count = 0
      
      # Parse results and create entities
      file_content.each_line do |line|
        result = JSON.parse(line)
        next unless result['response']['status_code'] == 200
        
        custom_id = result['custom_id']
        item_id = custom_id.split('_').last.to_i
        
        # Get the extracted entities from the response
        content = result['response']['body']['choices'][0]['message']['content']
        entities_data = JSON.parse(content)
        
        # Find the item
        item = SearchableItem.find_by(id: item_id)
        next unless item
        
        # Delete existing entities for this item (to avoid duplicates)
        item.search_entities.destroy_all
        
        # Create new entities with pool awareness
        create_entities_for_item(item, entities_data, normalization_service)
        processed_count += 1
      end
      
      # Update cache status
      batch_info[:status] = 'completed'
      batch_info[:processed_count] = processed_count
      Rails.cache.write("batch_openai_#{batch_id}", batch_info, expires_in: 48.hours)
      
      Rails.logger.info "✅ Processed entity extraction results for #{processed_count} items"
    end
    
    private
    
    def build_extraction_request(item)
      {
        custom_id: "entity_#{item.id}",
        method: "POST",
        url: "/v1/chat/completions",
        body: {
          model: EXTRACTION_MODEL,
          messages: [
            { role: "system", content: build_enhanced_system_prompt(item.item_type) },
            { role: "user", content: build_extraction_text(item) }
          ],
          response_format: { type: "json_object" },
          temperature: 0.3,
          max_tokens: 1000
        }
      }
    end
    
    def build_enhanced_system_prompt(item_type)
      <<~PROMPT
        You are an advanced entity extraction system for the Burning Man dataset, implementing the Seven Pools of Enliteracy framework.
        
        Extract entities that connect to these seven pools of meaning:
        
        1. IDEA POOL - Philosophical concepts, principles, cultural values
        2. MANIFEST POOL - Physical items, structures, tangible creations
        3. EXPERIENCE POOL - Emotions, transformations, sensory descriptions
        4. RELATIONAL POOL - Connections, collaborations, communities
        5. EVOLUTIONARY POOL - Changes over time, historical references, innovations
        6. PRACTICAL POOL - Skills, techniques, how-to knowledge
        7. EMANATION POOL - Broader impacts, cultural influences, ripple effects
        
        Return a JSON object with both traditional entities AND pool-specific entities:
        
        {
          "traditional": {
            "locations": ["BRC addresses like 7:30 & C"],
            "activities": ["workshops, performances, services"],
            "themes": ["art themes, camp concepts"],
            "times": ["time references"],
            "people": ["notable people mentioned"]
          },
          "pools": {
            "idea": ["principles referenced", "philosophical concepts", "cultural values"],
            "manifest": ["physical structures", "art pieces", "tangible offerings"],
            "experience": ["emotions", "transformative moments", "sensory descriptions"],
            "relational": ["collaborations", "communities", "connections mentioned"],
            "evolutionary": ["historical references", "changes noted", "innovations"],
            "practical": ["skills taught", "techniques described", "how-to elements"],
            "emanation": ["broader impacts", "influences beyond BRC", "cultural movements"]
          },
          "cross_pool_flows": [
            {
              "from_pool": "idea",
              "to_pool": "manifest",
              "concept": "what idea manifests as what"
            }
          ]
        }
        
        Focus on high-confidence extractions. Consider the item type: #{item_type}
      PROMPT
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
    
    def create_entities_for_item(item, entities_data, normalization_service)
      # Process traditional entities
      if entities_data['traditional'].present?
        entity_mappings = {
          "locations" => "location",
          "activities" => "activity", 
          "themes" => "theme",
          "times" => "time",
          "people" => "person"
        }
        
        entity_mappings.each do |key, entity_type|
          next unless entities_data['traditional'][key].is_a?(Array)
          
          entities_data['traditional'][key].each do |value|
            normalized_value = normalization_service.normalize_entity(entity_type, value.to_s.strip)
            
            SearchEntity.create!(
              searchable_item: item,
              entity_type: entity_type,
              entity_value: normalized_value,
              confidence_score: 0.9,
              metadata: { source: 'batch_extraction', extraction_version: 'v2_pools' }
            )
          end
        end
      end
      
      # Process pool-specific entities
      if entities_data['pools'].present?
        entities_data['pools'].each do |pool, entities|
          next unless entities.is_a?(Array)
          
          entities.each do |value|
            # Pool entities get special entity_type to distinguish them
            SearchEntity.create!(
              searchable_item: item,
              entity_type: "pool_#{pool}",
              entity_value: value.to_s.strip.downcase,
              confidence_score: 0.85,
              metadata: { 
                source: 'batch_extraction',
                extraction_version: 'v2_pools',
                pool: pool
              }
            )
          end
        end
      end
      
      # Process cross-pool flows
      if entities_data['cross_pool_flows'].present? && entities_data['cross_pool_flows'].is_a?(Array)
        entities_data['cross_pool_flows'].each do |flow|
          SearchEntity.create!(
            searchable_item: item,
            entity_type: "flow",
            entity_value: flow['concept'],
            confidence_score: 0.8,
            metadata: {
              source: 'batch_extraction',
              extraction_version: 'v2_pools',
              from_pool: flow['from_pool'],
              to_pool: flow['to_pool']
            }
          )
        end
      end
      
      Rails.logger.info "Created entities for item #{item.id} (#{item.name})"
    rescue => e
      Rails.logger.error "Error creating entities for item #{item.id}: #{e.message}"
    end
  end
end