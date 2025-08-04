# frozen_string_literal: true

module Search
  class BiographicalContentImportService
    # Import biographical content (writings, speeches, essays) into enliterated dataset
    # Designed for adding persona-specific content like Larry Harvey's writings
    
    def initialize
      @embedding_service = EmbeddingService.new
      @entity_service = EntityExtractionService.new
    end
    
    def import_text_files(directory_path, persona_name:, author_id: nil, default_year: 2024)
      Rails.logger.info "Importing biographical content from #{directory_path} for #{persona_name}"
      
      unless Dir.exist?(directory_path)
        Rails.logger.error "Directory not found: #{directory_path}"
        return { success: false, error: "Directory not found" }
      end
      
      # Find all text files
      text_files = Dir.glob(File.join(directory_path, "**/*.{txt,md,text}"))
      
      if text_files.empty?
        Rails.logger.warn "No text files found in #{directory_path}"
        return { success: true, imported: 0, message: "No text files found" }
      end
      
      results = {
        success: true,
        imported: 0,
        failed: 0,
        items: [],
        errors: []
      }
      
      text_files.each do |file_path|
        begin
          result = import_single_file(file_path, persona_name, author_id, default_year)
          
          if result[:success]
            results[:imported] += 1
            results[:items] << result[:item]
            Rails.logger.info "✓ Imported: #{File.basename(file_path)}"
          else
            results[:failed] += 1
            results[:errors] << { file: file_path, error: result[:error] }
            Rails.logger.error "✗ Failed: #{File.basename(file_path)} - #{result[:error]}"
          end
          
        rescue => e
          results[:failed] += 1
          results[:errors] << { file: file_path, error: e.message }
          Rails.logger.error "✗ Exception importing #{file_path}: #{e.message}"
        end
      end
      
      Rails.logger.info "Import complete: #{results[:imported]} imported, #{results[:failed]} failed"
      results
    end
    
    def import_single_file(file_path, persona_name, author_id, default_year)
      content = File.read(file_path, encoding: 'UTF-8')
      filename = File.basename(file_path, File.extname(file_path))
      
      # Parse metadata from filename or content
      metadata = parse_metadata(filename, content)
      
      # Determine item type based on content analysis
      item_type = determine_item_type(content, filename)
      
      # Extract year from filename or metadata
      year = extract_year(filename, content) || metadata[:year] || default_year
      
      # Generate unique ID
      uid = generate_uid(persona_name, filename, year)
      
      # Check if already exists
      existing = SearchableItem.find_by(uid: uid)
      if existing
        Rails.logger.info "Item already exists: #{uid}"
        return { success: true, item: existing, message: "Already exists" }
      end
      
      # Create searchable item
      searchable_item = SearchableItem.new(
        uid: uid,
        item_type: item_type,
        year: year,
        name: metadata[:title] || format_title(filename),
        description: extract_description(content),
        location_string: nil, # Not applicable for writings
        metadata: {
          'original_filename' => File.basename(file_path),
          'author' => persona_name,
          'author_id' => author_id,
          'word_count' => content.split.length,
          'import_date' => Time.current.iso8601,
          'content_type' => 'biographical_writing',
          'source' => 'direct_import'
        }.merge(metadata)
      )
      
      # Set searchable text (combines title + description for embedding)
      searchable_item.searchable_text = "#{searchable_item.name} #{content}".strip
      
      if searchable_item.save
        # Generate embedding
        generate_embedding(searchable_item, content)
        
        # Extract entities
        extract_entities(searchable_item, content)
        
        { success: true, item: searchable_item }
      else
        { success: false, error: searchable_item.errors.full_messages.join(', ') }
      end
    end
    
    private
    
    def parse_metadata(filename, content)
      metadata = {}
      
      # Try to extract metadata from YAML front matter
      if content.start_with?('---')
        yaml_end = content.index('---', 3)
        if yaml_end
          begin
            yaml_content = content[3...yaml_end]
            yaml_data = YAML.safe_load(yaml_content, permitted_classes: [Date, Time])
            metadata.merge!(yaml_data.symbolize_keys)
            # Remove YAML front matter from content
            content.replace(content[(yaml_end + 3)..-1].strip)
          rescue => e
            Rails.logger.warn "Failed to parse YAML front matter: #{e.message}"
          end
        end
      end
      
      # Extract year from filename patterns
      if filename.match(/(\d{4})/)
        metadata[:year] = $1.to_i
      end
      
      # Look for title in first line if not in metadata
      unless metadata[:title]
        first_line = content.lines.first&.strip
        if first_line && first_line.length < 100 && !first_line.include?('.')
          metadata[:title] = first_line.gsub(/^#+\s*/, '') # Remove markdown headers
        end
      end
      
      metadata
    end
    
    def determine_item_type(content, filename)
      # Analyze content to determine appropriate item type
      content_lower = content.downcase
      filename_lower = filename.downcase
      
      case
      when filename_lower.include?('principle') || content_lower.include?('principle')
        'philosophical_text'
      when filename_lower.include?('speech') || filename_lower.include?('address')
        'speech'
      when filename_lower.include?('essay') || filename_lower.include?('writing')
        'essay'
      when filename_lower.include?('manifesto') || filename_lower.include?('statement')
        'manifesto'
      when filename_lower.include?('interview') || content_lower.include?('interview')
        'interview'
      when filename_lower.include?('letter') || content_lower.include?('dear ')
        'letter'
      when content.split.length < 500 # Short content
        'note'
      else
        'essay' # Default for longer writings
      end
    end
    
    def extract_year(filename, content)
      # Try filename first
      year_match = filename.match(/(\d{4})/)
      return year_match[1].to_i if year_match
      
      # Try content for year references
      year_matches = content.scan(/\b(19\d{2}|20\d{2})\b/).flatten.map(&:to_i)
      if year_matches.any?
        # Return the most recent year that's not in the future
        current_year = Time.current.year
        valid_years = year_matches.select { |y| y <= current_year && y >= 1986 } # Burning Man started 1986
        return valid_years.max if valid_years.any?
      end
      
      nil
    end
    
    def generate_uid(persona_name, filename, year)
      # Create unique identifier
      base = "#{persona_name.downcase.gsub(/\s+/, '_')}_#{filename.downcase.gsub(/[^a-z0-9]/, '_')}_#{year}"
      "biographical_#{base}"
    end
    
    def format_title(filename)
      # Convert filename to readable title
      filename.gsub(/[_-]/, ' ')
              .split(' ')
              .map(&:capitalize)
              .join(' ')
    end
    
    def extract_description(content)
      # Extract first paragraph or meaningful chunk as description
      paragraphs = content.split(/\n\s*\n/).reject(&:blank?)
      
      return content if paragraphs.length <= 1
      
      # Use first substantial paragraph
      first_para = paragraphs.first.strip
      
      # If first paragraph is very short, combine with second
      if first_para.length < 100 && paragraphs.length > 1
        first_para += "\n\n" + paragraphs.second.strip
      end
      
      # Truncate if too long
      if first_para.length > 2000
        first_para = first_para[0, 1997] + "..."
      end
      
      first_para
    end
    
    def generate_embedding(searchable_item, content)
      # Use the full content for embedding, not just description
      embedding_text = "#{searchable_item.name}\n\n#{content}"
      
      embedding = @embedding_service.generate_embedding(embedding_text)
      
      if embedding
        searchable_item.update_columns(
          embedding: embedding,
          updated_at: Time.current
        )
        Rails.logger.debug "Generated embedding for #{searchable_item.uid}"
      else
        Rails.logger.warn "Failed to generate embedding for #{searchable_item.uid}"
      end
    rescue => e
      Rails.logger.error "Error generating embedding for #{searchable_item.uid}: #{e.message}"
    end
    
    def extract_entities(searchable_item, content)
      # Use full content for entity extraction
      full_text = "#{searchable_item.name}\n\n#{content}"
      
      entities = @entity_service.extract_entities(full_text, searchable_item.item_type)
      
      # Add biographical-specific entities
      biographical_entities = extract_biographical_entities(content, searchable_item)
      entities.concat(biographical_entities)
      
      entities.each do |entity_data|
        searchable_item.search_entities.create!(entity_data)
      end
      
      Rails.logger.debug "Extracted #{entities.length} entities for #{searchable_item.uid}"
    rescue => e
      Rails.logger.error "Error extracting entities for #{searchable_item.uid}: #{e.message}"
    end
    
    def extract_biographical_entities(content, item)
      entities = []
      
      # Add the author as a person entity
      if item.metadata['author']
        entities << {
          entity_type: 'person',
          entity_value: item.metadata['author'],
          confidence: 1.0
        }
      end
      
      # Look for Burning Man specific terms
      burning_man_terms = {
        'burning man' => 'event',
        'black rock city' => 'location',
        'black rock desert' => 'location',
        'playa' => 'location',
        'effigy' => 'art',
        'temple' => 'art',
        'gift economy' => 'concept',
        'radical self-reliance' => 'principle',
        'radical inclusion' => 'principle',
        'radical self-expression' => 'principle',
        'decommodification' => 'principle',
        'ten principles' => 'philosophy'
      }
      
      content_lower = content.downcase
      burning_man_terms.each do |term, type|
        if content_lower.include?(term)
          entities << {
            entity_type: type,
            entity_value: term.titleize,
            confidence: 0.9
          }
        end
      end
      
      entities
    end
  end
end