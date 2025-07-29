module Search
  class DataImportService
    BATCH_SIZE = 50
    
    def initialize
      @embedding_service = EmbeddingService.new
      @entity_service = EntityExtractionService.new
    end
    
    def import_year_data(year)
      Rails.logger.info("Starting data import for year #{year}")
      
      import_camps(year)
      import_art(year)
      import_events(year)
      
      Rails.logger.info("Data import completed for year #{year}")
    end
    
    def import_camps(year)
      file_path = Rails.root.join("..", "frontend", "public", "data", year.to_s, "camps.json")
      return unless File.exist?(file_path)
      
      Rails.logger.info("Importing camps from #{file_path}")
      
      camps = JSON.parse(File.read(file_path))
      process_items(camps, 'camp', year)
    end
    
    def import_art(year)
      file_path = Rails.root.join("..", "frontend", "public", "data", year.to_s, "art.json")
      return unless File.exist?(file_path)
      
      Rails.logger.info("Importing art from #{file_path}")
      
      art_items = JSON.parse(File.read(file_path))
      process_items(art_items, 'art', year)
    end
    
    def import_events(year)
      file_path = Rails.root.join("..", "frontend", "public", "data", year.to_s, "events.json")
      return unless File.exist?(file_path)
      
      Rails.logger.info("Importing events from #{file_path}")
      
      events = JSON.parse(File.read(file_path))
      process_items(events, 'event', year)
    end
    
    private
    
    def process_items(items, item_type, year)
      total = items.count
      Rails.logger.info("Processing #{total} #{item_type} items")
      
      items.each_slice(BATCH_SIZE).with_index do |batch, batch_index|
        Rails.logger.info("Processing batch #{batch_index + 1} (#{batch.size} items)")
        
        # Create searchable items
        searchable_items = batch.map do |item|
          create_searchable_item(item, item_type, year)
        end.compact
        
        # Generate embeddings in batch
        generate_embeddings_batch(searchable_items)
        
        # Extract entities for each item
        extract_entities_batch(searchable_items)
        
        Rails.logger.info("Batch #{batch_index + 1} completed")
      end
    end
    
    def create_searchable_item(item, item_type, year)
      # Skip if already exists
      existing = SearchableItem.find_by(uid: item['uid'])
      return existing if existing
      
      searchable_item = SearchableItem.new(
        uid: item['uid'],
        item_type: item_type,
        year: year,
        name: extract_name(item, item_type),
        description: item['description'],
        metadata: item
      )
      
      searchable_item.prepare_searchable_text
      
      if searchable_item.save
        searchable_item
      else
        Rails.logger.error("Failed to save #{item_type} #{item['uid']}: #{searchable_item.errors.full_messages}")
        nil
      end
    rescue => e
      Rails.logger.error("Error creating searchable item: #{e.message}")
      nil
    end
    
    def extract_name(item, item_type)
      case item_type
      when 'event'
        item['title'] || item['name']
      else
        item['name']
      end
    end
    
    def generate_embeddings_batch(items)
      return if items.empty?
      
      # Get texts for all items
      texts = items.map(&:searchable_text)
      
      # Generate embeddings in batch
      embeddings = @embedding_service.generate_embeddings_batch(texts)
      
      # Update items with embeddings
      items.zip(embeddings).each do |item, embedding|
        next unless embedding
        
        item.update_columns(
          embedding: embedding,
          updated_at: Time.current
        )
      end
    rescue => e
      Rails.logger.error("Error generating embeddings: #{e.message}")
    end
    
    def extract_entities_batch(items)
      items.each do |item|
        next if item.search_entities.exists?
        
        entities = @entity_service.extract_entities(
          item.searchable_text,
          item.item_type
        )
        
        entities.each do |entity_data|
          item.search_entities.create!(entity_data)
        end
      rescue => e
        Rails.logger.error("Error extracting entities for #{item.uid}: #{e.message}")
      end
    end
  end
end