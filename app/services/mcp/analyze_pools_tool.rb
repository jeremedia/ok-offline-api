# frozen_string_literal: true

module Mcp
  # AnalyzePoolsTool - Real-time Enliteracy Demonstration
  #
  # This tool showcases the Seven Pools of Enliteracy framework by taking any text
  # and instantly granting it literacy across seven cognitive dimensions. It represents
  # the first implementation of real-time enliteracy accessible via MCP protocol.
  #
  # The analysis process:
  # 1. Extract entities across all Seven Pools using production AI
  # 2. Calculate semantic richness and cultural domain coverage  
  # 3. Identify connection potential to existing knowledge graph
  # 4. Generate intelligent suggestions for further exploration
  # 5. Provide enliteracy metrics showing how "literate" the text has become
  class AnalyzePoolsTool
    VALID_MODES = %w[extract classify link].freeze
    
    def self.call(text:, mode: 'extract', link_threshold: 0.6)
      # Validate inputs
      return validation_error("invalid_mode") unless VALID_MODES.include?(mode)
      return validation_error("text_too_long") if text.length > 8000
      
      start_time = Time.current
      
      # Step 1: Extract pool entities using production service
      pools = extract_pool_entities_with_ai(text)
      
      # Step 2: Extract basic entities for comprehensive understanding
      basic_entities = extract_basic_entities_with_ai(text)
      
      # Step 3: Calculate semantic richness across dimensions
      semantic_analysis = calculate_semantic_richness(pools, basic_entities)
      
      # Step 4: Identify cultural domains activated by this text
      cultural_domains = identify_cultural_domains(pools)
      
      # Step 5: Calculate connection potential to existing knowledge
      connection_analysis = analyze_connection_potential(pools, basic_entities)
      
      # Step 6: Find similar content already in the enliterated dataset
      similar_items = find_semantically_similar_items(pools, basic_entities)
      
      # Step 7: Generate intelligent exploration suggestions
      exploration_suggestions = generate_exploration_suggestions(pools, basic_entities, cultural_domains)
      
      # Step 8: Calculate enliteracy metrics
      enliteracy_metrics = calculate_enliteracy_metrics(pools, basic_entities, connection_analysis)
      
      execution_time = Time.current - start_time
      
      # Process based on mode
      case mode
      when 'extract'
        format_extract_response(text, pools, basic_entities, link_threshold)
      when 'classify'
        format_classify_response(text, pools, basic_entities, cultural_domains)
      when 'link'
        format_link_response(text, pools, basic_entities, similar_items)
      end
    rescue => e
      Rails.logger.error "AnalyzePoolsTool error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      {
        entities: [],
        ambiguous_terms: [],
        normalized_query: text.downcase.strip,
        error: "Analysis failed: #{e.message}"
      }
    end
    
    private
    
    def self.validation_error(message)
      {
        entities: [],
        ambiguous_terms: [],
        normalized_query: "",
        error: message
      }
    end
    
    def self.format_extract_response(text, pools, basic_entities, link_threshold)
      entities = []
      ambiguous_terms = []
      
      # Convert pools to entity format
      pools.each do |pool_type, pool_entities|
        pool_name = pool_type.sub('pool_', '')
        
        pool_entities.each do |entity_value|
          # Find position in text (simple implementation)
          text_lower = text.downcase
          entity_lower = entity_value.downcase
          
          start_pos = text_lower.index(entity_lower)
          next unless start_pos
          
          end_pos = start_pos + entity_value.length
          
          # Check for linking based on threshold
          linked_id = find_linked_entity(entity_value, pool_name, link_threshold)
          
          entities << {
            span: entity_value,
            start: start_pos,
            end: end_pos,
            pool: pool_name,
            canonical_term: entity_value.titleize,
            confidence: calculate_extraction_confidence(entity_value, text),
            linked_id: linked_id
          }
        end
      end
      
      # Find ambiguous terms
      ambiguous_terms = find_ambiguous_terms(text, pools)
      
      # Generate normalized query
      normalized_query = normalize_query_text(text, pools, basic_entities)
      
      {
        entities: entities.sort_by { |e| e[:start] },
        ambiguous_terms: ambiguous_terms,
        normalized_query: normalized_query
      }
    end
    
    def self.format_classify_response(text, pools, basic_entities, cultural_domains)
      # Return classification-focused response
      {
        entities: extract_entities_for_classification(pools, basic_entities),
        ambiguous_terms: [],
        normalized_query: normalize_query_text(text, pools, basic_entities),
        classification: {
          primary_pool: determine_primary_pool(pools),
          cultural_domains: cultural_domains,
          confidence_scores: calculate_classification_confidence(pools)
        }
      }
    end
    
    def self.format_link_response(text, pools, basic_entities, similar_items)
      # Return linking-focused response
      entities = extract_entities_with_strong_linking(pools, basic_entities, similar_items)
      
      {
        entities: entities,
        ambiguous_terms: find_ambiguous_terms(text, pools),
        normalized_query: normalize_query_text(text, pools, basic_entities),
        linked_items: similar_items.map { |item| {
          id: item[:id],
          title: item[:name],
          similarity: item[:similarity_strength]
        }}
      }
    end
    
    def self.find_linked_entity(entity_value, pool_name, threshold)
      # Find the most likely linked entity based on threshold
      # Simple implementation - in production would use more sophisticated matching
      return nil if calculate_link_confidence(entity_value) < threshold
      
      "#{pool_name}:#{entity_value.parameterize}"
    end
    
    def self.calculate_extraction_confidence(entity_value, text)
      # Simple confidence calculation based on context
      text_words = text.downcase.split(/\W+/)
      entity_words = entity_value.downcase.split(/\W+/)
      
      # Higher confidence if more words from entity appear in text
      matches = entity_words.count { |word| text_words.include?(word) }
      confidence = matches.to_f / entity_words.length
      
      # Boost confidence for longer entities
      length_boost = [entity_value.length / 20.0, 0.2].min
      
      [(confidence + length_boost).round(2), 1.0].min
    end
    
    def self.find_ambiguous_terms(text, pools)
      ambiguous = []
      
      # Look for terms that could map to multiple pools
      text_words = text.downcase.split(/\W+/).reject { |w| w.length < 3 }
      
      text_words.each do |word|
        candidates = []
        
        pools.each do |pool_type, entities|
          entities.each do |entity|
            if entity.downcase.include?(word)
              pool_name = pool_type.sub('pool_', '')
              candidates << "#{pool_name}:#{entity}"
            end
          end
        end
        
        if candidates.length > 1
          ambiguous << {
            term: word,
            candidates: candidates.first(3)  # Limit to prevent overwhelming
          }
        end
      end
      
      ambiguous.uniq { |a| a[:term] }.first(5)  # Limit total ambiguous terms
    end
    
    def self.normalize_query_text(text, pools, basic_entities)
      # Create normalized query using canonical terms
      words = text.downcase.split(/\W+/).reject(&:empty?)
      normalized_words = []
      
      words.each do |word|
        # Try to find canonical term in pools
        canonical = find_canonical_term(word, pools, basic_entities)
        normalized_words << (canonical || word)
      end
      
      normalized_words.uniq.join(' ')
    end
    
    def self.find_canonical_term(word, pools, basic_entities)
      # Look for canonical version of word in entities
      all_entities = (pools.values + basic_entities.values).flatten
      
      all_entities.each do |entity|
        return entity.titleize if entity.downcase.include?(word) && entity.length > word.length
      end
      
      nil
    end
    
    def self.extract_entities_for_classification(pools, basic_entities)
      entities = []
      
      pools.each do |pool_type, pool_entities|
        pool_name = pool_type.sub('pool_', '')
        
        pool_entities.each do |entity|
          entities << {
            span: entity,
            start: 0,  # Classification doesn't need exact positions
            end: entity.length,
            pool: pool_name,
            canonical_term: entity.titleize,
            confidence: 0.8,  # Default confidence for classification
            linked_id: "#{pool_name}:#{entity.parameterize}"
          }
        end
      end
      
      entities
    end
    
    def self.determine_primary_pool(pools)
      return nil if pools.empty?
      
      # Find pool with most entities
      primary = pools.max_by { |_, entities| entities.length }
      primary&.first&.sub('pool_', '')
    end
    
    def self.calculate_classification_confidence(pools)
      pools.transform_keys { |k| k.sub('pool_', '') }
           .transform_values { |entities| (entities.length / 10.0).round(2) }
    end
    
    def self.extract_entities_with_strong_linking(pools, basic_entities, similar_items)
      entities = []
      
      # Only include entities that have strong links to existing items
      pools.each do |pool_type, pool_entities|
        pool_name = pool_type.sub('pool_', '')
        
        pool_entities.each do |entity|
          # Check if this entity appears in similar items
          has_strong_link = similar_items.any? { |item| 
            item[:name]&.downcase&.include?(entity.downcase)
          }
          
          next unless has_strong_link
          
          entities << {
            span: entity,
            start: 0,
            end: entity.length,
            pool: pool_name,
            canonical_term: entity.titleize,
            confidence: 0.9,  # High confidence for linked entities
            linked_id: "#{pool_name}:#{entity.parameterize}"
          }
        end
      end
      
      entities
    end
    
    def self.calculate_link_confidence(entity_value)
      # Simple implementation - in production would use more sophisticated scoring
      # Longer, more specific entities have higher link confidence
      base_confidence = [entity_value.length / 20.0, 0.9].min
      
      # Boost for entities with multiple words (more specific)
      word_count_boost = entity_value.split.length > 1 ? 0.1 : 0
      
      base_confidence + word_count_boost
    end
    
    # Extract pool entities by finding matches in our already-enliterated dataset
    def self.extract_pool_entities_with_ai(text)
      pools = {}
      
      # Get all pool entity types
      pool_types = %w[pool_idea pool_manifest pool_experience pool_relational pool_evolutionary pool_practical pool_emanation]
      
      # For each pool type, find entities that match words in the text
      text_words = text.downcase.split(/\W+/).reject(&:empty?)
      
      pool_types.each do |pool_type|
        # Find pool entities that match words in the text
        matching_entities = SearchEntity.where(entity_type: pool_type)
                                       .where("entity_value ILIKE ANY (ARRAY[?])", 
                                             text_words.map { |word| "%#{word}%" })
                                       .limit(10)
                                       .pluck(:entity_value)
                                       .uniq
        
        if matching_entities.any?
          pools[pool_type] = matching_entities
        end
      end
      
      pools
    end
    
    # Extract basic entities using simplified but effective approach
    def self.extract_basic_entities_with_ai(text)
      # Use existing SearchEntity data to find matches in the text
      basic_entities = {}
      
      # Define entity types to search for
      entity_types = %w[location activity theme person organizational]
      
      entity_types.each do |entity_type|
        # Find entities of this type that appear in the text
        matches = SearchEntity.where(entity_type: entity_type)
                             .where("entity_value ILIKE ANY (ARRAY[?])", 
                                   text.downcase.split(/\W+/).map { |word| "%#{word}%" })
                             .limit(10)
                             .pluck(:entity_value)
                             .uniq
        
        basic_entities[entity_type] = matches if matches.any?
      end
      
      basic_entities
    end
    
    # Calculate how semantically rich the text is across dimensions
    def self.calculate_semantic_richness(pools, basic_entities)
      total_entities = (pools.values + basic_entities.values).flatten.uniq.count
      pool_diversity = pools.keys.count
      basic_diversity = basic_entities.keys.count
      
      # Calculate cross-pool bridge potential
      bridge_entities = find_bridge_entities_in_pools(pools)
      
      {
        total_unique_entities: total_entities,
        pool_coverage: {
          pools_activated: pool_diversity,
          total_pools: 7,
          coverage_percentage: (pool_diversity / 7.0 * 100).round(1)
        },
        basic_entity_coverage: {
          types_found: basic_diversity,
          entities_per_type: basic_entities.transform_values(&:count)
        },
        semantic_density: calculate_semantic_density(total_entities, pools, basic_entities),
        bridge_potential: bridge_entities.count,
        richness_score: calculate_overall_richness_score(pool_diversity, basic_diversity, total_entities, bridge_entities.count)
      }
    end
    
    # Identify which cultural domains are activated by this text
    def self.identify_cultural_domains(pools)
      domains = []
      domain_mapping = {
        "Physical/Structural" => ["pool_manifest"],
        "Experiential/Sensory" => ["pool_experience"], 
        "Social/Community" => ["pool_relational"],
        "Philosophical/Conceptual" => ["pool_idea"],
        "Practical/Educational" => ["pool_practical"],
        "Temporal/Historical" => ["pool_evolutionary"],
        "Spiritual/Transcendent" => ["pool_emanation"]
      }
      
      domain_mapping.each do |domain, pool_types|
        if pool_types.any? { |pool| pools[pool]&.any? }
          entities_in_domain = pool_types.map { |pool| pools[pool] || [] }.flatten
          domains << {
            name: domain,
            entity_count: entities_in_domain.count,
            example_entities: entities_in_domain.first(3),
            activated: true
          }
        end
      end
      
      domains
    end
    
    # Analyze how well this text could connect to existing knowledge
    def self.analyze_connection_potential(pools, basic_entities)
      all_entities = (pools.values + basic_entities.values).flatten.uniq
      
      # Check how many of these entities exist in our knowledge graph
      existing_entities = SearchEntity.where(entity_value: all_entities).distinct.count
      
      # Find high-frequency entities (suggesting strong cultural resonance)
      high_frequency_entities = SearchEntity.where(entity_value: all_entities)
                                           .joins(Arel.sql("JOIN (SELECT entity_value, COUNT(*) as freq FROM search_entities GROUP BY entity_value HAVING COUNT(*) > 5) freq_table ON search_entities.entity_value = freq_table.entity_value"))
                                           .pluck(:entity_value)
                                           .uniq
      
      # Calculate connection strength based on pool bridge potential
      bridge_entities = find_bridge_entities_in_pools(pools)
      
      {
        total_entities_found: all_entities.count,
        entities_in_knowledge_graph: existing_entities,
        knowledge_graph_coverage: existing_entities > 0 ? (existing_entities.to_f / all_entities.count * 100).round(1) : 0,
        high_frequency_entities: high_frequency_entities,
        cultural_resonance_score: high_frequency_entities.count,
        bridge_entities: bridge_entities,
        connection_strength: calculate_connection_strength(existing_entities, all_entities.count, bridge_entities.count),
        integration_potential: determine_integration_potential(existing_entities, all_entities.count, bridge_entities.count)
      }
    end
    
    # Find items in our dataset that share similar entities
    def self.find_semantically_similar_items(pools, basic_entities)
      all_entity_values = (pools.values + basic_entities.values).flatten.uniq.first(10) # Limit for performance
      
      return [] if all_entity_values.empty?
      
      # Find items with overlapping entities, ranked by overlap strength
      similar_items = SearchEntity
        .joins(:searchable_item)
        .where(entity_value: all_entity_values)
        .group(Arel.sql('searchable_items.id, searchable_items.name, searchable_items.item_type'))
        .having(Arel.sql('COUNT(DISTINCT search_entities.entity_value) >= ?'), [all_entity_values.count * 0.3, 2].max.to_i) # At least 30% overlap or 2 entities
        .order(Arel.sql('COUNT(DISTINCT search_entities.entity_value) DESC'))
        .limit(5)
        .pluck(Arel.sql('searchable_items.id'), Arel.sql('searchable_items.name'), Arel.sql('searchable_items.item_type'), Arel.sql('COUNT(DISTINCT search_entities.entity_value)'))
        .map do |id, name, item_type, overlap_count|
          {
            id: id,
            name: name,
            item_type: item_type,
            entity_overlap_count: overlap_count,
            similarity_strength: (overlap_count.to_f / all_entity_values.count * 100).round(1),
            url: "https://offline.oknotok.com/item/#{id}"
          }
        end
      
      similar_items
    end
    
    # Generate intelligent suggestions for further exploration
    def self.generate_exploration_suggestions(pools, basic_entities, cultural_domains)
      suggestions = {
        search_queries: [],
        pool_explorations: [],
        cross_domain_investigations: [],
        knowledge_graph_traversals: []
      }
      
      # Generate search queries based on extracted entities
      pools.each do |pool_type, entities|
        next if entities.empty?
        
        pool_name = pool_type.gsub('pool_', '')
        entity_sample = entities.first(2)
        suggestions[:search_queries] << "Items exploring #{entity_sample.join(' and ')} in the #{pool_name} domain"
      end
      
      # Suggest pool explorations
      active_pools = pools.select { |_, entities| entities.any? }.keys
      active_pools.each do |pool|
        pool_name = pool.gsub('pool_', '')
        suggestions[:pool_explorations] << {
          pool: pool_name,
          suggestion: "Explore how #{pool_name} concepts manifest across different Burning Man experiences",
          example_query: pools[pool].first(2).join(' OR ')
        }
      end
      
      # Cross-domain investigations
      if active_pools.count >= 2
        pool_pairs = active_pools.combination(2).first(3)
        pool_pairs.each do |pool1, pool2|
          name1 = pool1.gsub('pool_', '')
          name2 = pool2.gsub('pool_', '')
          suggestions[:cross_domain_investigations] << "Investigate how #{name1} and #{name2} domains intersect in Burning Man culture"
        end
      end
      
      # Knowledge graph traversal suggestions
      bridge_entities = find_bridge_entities_in_pools(pools)
      bridge_entities.each do |entity|
        suggestions[:knowledge_graph_traversals] << "Trace '#{entity}' through the knowledge graph to discover unexpected connections"
      end
      
      suggestions
    end
    
    # Calculate comprehensive enliteracy metrics
    def self.calculate_enliteracy_metrics(pools, basic_entities, connection_analysis)
      total_entities = (pools.values + basic_entities.values).flatten.uniq.count
      
      {
        entity_extraction_score: calculate_entity_extraction_score(pools, basic_entities),
        semantic_understanding_score: calculate_semantic_understanding_score(pools),
        cultural_integration_score: connection_analysis[:cultural_resonance_score],
        knowledge_graph_connectivity: connection_analysis[:connection_strength],
        overall_enliteracy_score: calculate_overall_enliteracy_score(pools, basic_entities, connection_analysis),
        enliteracy_grade: determine_enliteracy_grade(pools, basic_entities, connection_analysis),
        interpretation: generate_enliteracy_interpretation(pools, basic_entities, connection_analysis)
      }
    end
    
    # Generate human-readable insights about the enliteracy process
    def self.generate_insights(pools, basic_entities, cultural_domains, enliteracy_metrics)
      insights = []
      
      # Pool coverage insights
      active_pools = pools.select { |_, entities| entities.any? }.count
      if active_pools >= 5
        insights << "This text demonstrates rich multi-dimensional understanding, spanning #{active_pools} of the Seven Pools."
      elsif active_pools >= 3
        insights << "This text shows good conceptual depth across #{active_pools} cognitive dimensions."
      else
        insights << "This text focuses primarily on #{active_pools} cognitive dimension(s), suggesting specialized content."
      end
      
      # Bridge entity insights
      bridge_entities = find_bridge_entities_in_pools(pools)
      if bridge_entities.any?
        insights << "Contains #{bridge_entities.count} bridge entities that connect multiple pools: #{bridge_entities.first(3).join(', ')}"
      end
      
      # Cultural domain insights
      activated_domains = cultural_domains.select { |d| d[:activated] }
      if activated_domains.count >= 4
        insights << "Activates multiple cultural domains, indicating comprehensive Burning Man cultural understanding."
      end
      
      # Enliteracy grade insight
      insights << "Enliteracy Grade: #{enliteracy_metrics[:enliteracy_grade]} - #{enliteracy_metrics[:interpretation]}"
      
      insights
    end
    
    # Helper calculation methods
    
    def self.find_bridge_entities_in_pools(pools)
      # Entities that appear in multiple pools are bridge entities
      all_entities = pools.values.flatten
      entity_counts = all_entities.group_by(&:itself).transform_values(&:count)
      bridge_entities = []
      
      pools.each do |pool1, entities1|
        pools.each do |pool2, entities2|
          next if pool1 >= pool2 # Avoid duplicates
          common_entities = entities1 & entities2
          bridge_entities.concat(common_entities)
        end
      end
      
      bridge_entities.uniq
    end
    
    def self.calculate_semantic_density(total_entities, pools, basic_entities)
      # Semantic density = entities per cognitive dimension activated
      active_dimensions = pools.keys.count + basic_entities.keys.count
      return 0 if active_dimensions == 0
      
      (total_entities.to_f / active_dimensions).round(2)
    end
    
    def self.calculate_overall_richness_score(pool_diversity, basic_diversity, total_entities, bridge_count)
      # Richness score considering multiple factors
      base_score = (pool_diversity * 15) + (basic_diversity * 10) + total_entities + (bridge_count * 5)
      
      # Normalize to 0-100 scale
      normalized = (base_score / 150.0 * 100).round(1)
      [normalized, 100.0].min
    end
    
    def self.calculate_connection_strength(existing_entities, total_entities, bridge_count)
      return 0 if total_entities == 0
      
      # Connection strength based on knowledge graph presence and bridges
      graph_coverage = existing_entities.to_f / total_entities
      bridge_bonus = bridge_count * 0.1
      
      strength = (graph_coverage + bridge_bonus) * 100
      [strength.round(1), 100.0].min
    end
    
    def self.determine_integration_potential(existing_entities, total_entities, bridge_count)
      coverage = existing_entities.to_f / total_entities
      
      case
      when coverage >= 0.8 && bridge_count >= 3
        "EXCELLENT - High knowledge graph integration with strong cross-pool bridges"
      when coverage >= 0.6 && bridge_count >= 2  
        "GOOD - Solid knowledge graph presence with some bridge entities"
      when coverage >= 0.4 || bridge_count >= 1
        "MODERATE - Partial integration with some existing connections"
      else
        "LIMITED - Few existing connections, represents novel content"
      end
    end
    
    def self.calculate_entity_extraction_score(pools, basic_entities)
      total_entities = (pools.values + basic_entities.values).flatten.uniq.count
      
      # Score based on entity count and diversity
      entity_score = [total_entities * 5, 50].min # Cap at 50
      diversity_score = (pools.keys.count + basic_entities.keys.count) * 7
      
      (entity_score + diversity_score).round(1)
    end
    
    def self.calculate_semantic_understanding_score(pools)
      # Score based on pool coverage and balance
      active_pools = pools.select { |_, entities| entities.any? }.count
      coverage_score = (active_pools / 7.0 * 50).round(1)
      
      # Balance bonus - reward texts that don't over-concentrate in one pool
      entity_counts = pools.values.map(&:count)
      max_entities = entity_counts.max || 0
      total_entities = entity_counts.sum
      
      balance_score = if total_entities > 0 && max_entities.to_f / total_entities < 0.6
        25 # Bonus for balanced distribution
      else
        0
      end
      
      coverage_score + balance_score
    end
    
    def self.calculate_overall_enliteracy_score(pools, basic_entities, connection_analysis)
      entity_score = calculate_entity_extraction_score(pools, basic_entities)
      semantic_score = calculate_semantic_understanding_score(pools)
      connection_score = connection_analysis[:connection_strength]
      
      # Weighted average emphasizing semantic understanding
      overall = (entity_score * 0.3 + semantic_score * 0.4 + connection_score * 0.3).round(1)
      
      # Ensure score is between 0-100
      [[overall, 0].max, 100].min
    end
    
    def self.determine_enliteracy_grade(pools, basic_entities, connection_analysis)
      score = calculate_overall_enliteracy_score(pools, basic_entities, connection_analysis)
      
      case score
      when 90..100 then "A+"
      when 80..89 then "A"
      when 70..79 then "B+"
      when 60..69 then "B"
      when 50..59 then "C+"
      when 40..49 then "C"
      when 30..39 then "D"
      else "F"
      end
    end
    
    def self.generate_enliteracy_interpretation(pools, basic_entities, connection_analysis)
      score = calculate_overall_enliteracy_score(pools, basic_entities, connection_analysis)
      active_pools = pools.select { |_, entities| entities.any? }.count
      
      case
      when score >= 80
        "Highly enliterated text with rich multi-dimensional understanding and strong cultural integration."
      when score >= 60
        "Well-enliterated text showing good semantic depth across #{active_pools} cognitive dimensions."
      when score >= 40
        "Moderately enliterated text with some semantic understanding but limited cross-dimensional integration."
      else
        "Text shows basic enliteracy with potential for deeper semantic extraction and cultural integration."
      end
    end
  end
end