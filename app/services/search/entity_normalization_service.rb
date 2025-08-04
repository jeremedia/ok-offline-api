module Search
  class EntityNormalizationService
    # Define normalization rules for each entity type
    NORMALIZATION_RULES = {
      activity: {
        # Normalize to lowercase and singular forms
        'class/workshop' => ['workshop', 'workshops', 'class', 'classes'],
        'music/party' => ['party', 'parties', 'music party', 'dance party'],
        'arts & crafts' => ['art', 'arts', 'craft', 'crafts', 'art & craft'],
        'beverages' => ['drinks', 'drink', 'beverage', 'cocktails', 'cocktail'],
        'self care' => ['selfcare', 'self-care', 'wellness', 'healing'],
        'yoga/movement' => ['yoga', 'movement', 'fitness', 'exercise']
      },
      theme: {
        'music' => ['musical', 'musician', 'musicians'],
        'community' => ['communal', 'commune', 'communities'],
        'self-expression' => ['self expression', 'expression', 'express yourself'],
        'party' => ['parties', 'celebration', 'celebrate']
      },
      location: {
        'open playa' => ['playa', 'deep playa', 'open-playa'],
        'black rock city' => ['brc', 'black rock', 'blackrock city']
      }
    }.freeze
    
    # Create reverse mapping for fast lookups
    def self.build_reverse_mapping
      mapping = {}
      NORMALIZATION_RULES.each do |entity_type, rules|
        rules.each do |canonical, variations|
          # Add the canonical form
          mapping[[entity_type, canonical.downcase]] = canonical
          
          # Add all variations
          variations.each do |variation|
            mapping[[entity_type, variation.downcase]] = canonical
          end
        end
      end
      mapping
    end
    
    REVERSE_MAPPING = build_reverse_mapping.freeze
    
    def normalize_entity(entity_type, entity_value)
      return entity_value if entity_value.blank?
      
      # Convert to lowercase for comparison
      value_lower = entity_value.downcase.strip
      
      # Check if we have a mapping for this entity
      canonical = REVERSE_MAPPING[[entity_type.to_sym, value_lower]]
      
      if canonical
        canonical
      else
        # Apply general normalization rules
        normalize_general(entity_type, entity_value)
      end
    end
    
    def normalize_entity_list(entities)
      entities.map do |entity|
        if entity.is_a?(Array)
          type, value = entity
          [type, normalize_entity(type, value)]
        else
          entity[:entity_value] = normalize_entity(
            entity[:entity_type] || entity['entity_type'],
            entity[:entity_value] || entity['entity_value']
          )
          entity
        end
      end
    end
    
    private
    
    def normalize_general(entity_type, value)
      normalized = value.strip
      
      case entity_type.to_sym
      when :activity, :theme
        # Lowercase for activities and themes
        normalized = normalized.downcase
        
        # Remove trailing 's' for simple plurals
        normalized = normalized.gsub(/s\z/, '') if normalized.length > 3
        
        # Normalize common patterns
        normalized = normalized
          .gsub(/\s+&\s+/, ' & ')  # Normalize ampersands
          .gsub(/\s+/, ' ')         # Normalize whitespace
          .gsub(/[\/\-]/, '/')      # Normalize slashes
      when :location
        # Preserve case for locations but normalize spacing
        normalized = normalized
          .gsub(/\s+/, ' ')
          .gsub(/\s*&\s*/, ' & ')
      end
      
      normalized
    end
    
    # Method to analyze and suggest new normalization rules
    def self.analyze_entities(entity_type: nil, min_similarity: 0.8)
      
      scope = SearchEntity
      scope = scope.where(entity_type: entity_type) if entity_type
      
      # Get all unique entity values with counts
      entity_counts = scope.group(:entity_value).count
      
      # Sort by count to process most common first
      sorted_entities = entity_counts.sort_by { |_, count| -count }
      
      # Find similar entities
      suggestions = []
      processed = Set.new
      
      sorted_entities.each do |entity, count|
        next if processed.include?(entity.downcase)
        
        similar = []
        sorted_entities.each do |other, other_count|
          next if entity == other || processed.include?(other.downcase)
          
          # Calculate similarity (simple character-based for now)
          similarity = calculate_similarity(entity.downcase, other.downcase)
          
          if similarity >= min_similarity
            similar << { value: other, count: other_count, similarity: similarity }
          end
        end
        
        if similar.any?
          suggestions << {
            canonical: entity,
            count: count,
            similar: similar.sort_by { |s| -s[:similarity] }
          }
          
          # Mark all similar as processed
          similar.each { |s| processed.add(s[:value].downcase) }
        end
        
        processed.add(entity.downcase)
      end
      
      suggestions
    end
    
    def self.calculate_similarity(str1, str2)
      # Simple Levenshtein distance-based similarity
      return 1.0 if str1 == str2
      
      longer = [str1.length, str2.length].max
      return 0.0 if longer == 0
      
      edit_distance = levenshtein_distance(str1, str2)
      (longer - edit_distance) / longer.to_f
    end
    
    def self.levenshtein_distance(str1, str2)
      m = str1.length
      n = str2.length
      
      return m if n == 0
      return n if m == 0
      
      d = Array.new(m + 1) { Array.new(n + 1) }
      
      (0..m).each { |i| d[i][0] = i }
      (0..n).each { |j| d[0][j] = j }
      
      (1..n).each do |j|
        (1..m).each do |i|
          cost = str1[i - 1] == str2[j - 1] ? 0 : 1
          d[i][j] = [
            d[i - 1][j] + 1,      # deletion
            d[i][j - 1] + 1,      # insertion
            d[i - 1][j - 1] + cost # substitution
          ].min
        end
      end
      
      d[m][n]
    end
  end
end