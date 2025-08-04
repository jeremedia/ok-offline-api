# frozen_string_literal: true

module Mcp
  class PoolBridgeTool
    VALID_POOLS = %w[idea manifest experience relational evolutionary practical emanation].freeze
    
    def self.call(a:, b:, top_k: 10)
      # Validate and parse inputs - they can be pool names, entity IDs, or free text
      pool1, entity1 = parse_pool_input(a)
      pool2, entity2 = parse_pool_input(b)
      
      return validation_error("invalid_pool") if pool1 && !VALID_POOLS.include?(pool1)
      return validation_error("invalid_pool") if pool2 && !VALID_POOLS.include?(pool2)
      return validation_error("same_input") if a == b
      
      # Try Neo4j first, fallback to PostgreSQL
      begin
        service = Neo4jGraphService.new
        bridge_entities = find_bridge_entities_neo4j(service, pool1, pool2)
        bridge_items = find_bridge_items_neo4j(service, pool1, pool2)
        service&.close
      rescue => e
        Rails.logger.warn "Neo4j unavailable, using PostgreSQL fallback: #{e.message}"
        bridge_entities = find_bridge_entities_postgres(pool1, pool2)
        bridge_items = find_bridge_items_postgres(pool1, pool2)
      end
      
      # Format response according to Tool Contract v1.1
      bridges = format_bridge_results(bridge_items, pool1, pool2, entity1, entity2, top_k)
      
      {
        bridges: bridges
      }
    rescue => e
      Rails.logger.error "PoolBridgeTool error: #{e.message}"
      {
        bridges: [],
        error: "Bridge analysis failed: #{e.message}"
      }
    end
    
    private
    
    def self.validation_error(message)
      {
        bridges: [],
        error: message
      }
    end
    
    def self.parse_pool_input(input)
      # Parse input - could be pool name, entity ID, or free text
      input = input.to_s.strip.downcase
      
      # Check if it's a pool name
      if VALID_POOLS.include?(input)
        return [input, nil]
      end
      
      # Check if it's an entity ID (format: pool:entity)
      if input.include?(':')
        parts = input.split(':', 2)
        pool_name = parts[0]
        entity_name = parts[1]
        
        if VALID_POOLS.include?(pool_name)
          return [pool_name, entity_name]
        end
      end
      
      # Treat as free text - try to extract pool entities
      detected_pool = detect_pool_from_text(input)
      [detected_pool, input]
    end
    
    def self.detect_pool_from_text(text)
      # Simple detection - look for pool entities in the text
      text_words = text.split(/\W+/).reject(&:empty?)
      
      VALID_POOLS.each do |pool|
        pool_type = "pool_#{pool}"
        
        # Check if any entities of this pool type appear in the text
        matches = SearchEntity.where(entity_type: pool_type)
                             .where("entity_value ILIKE ANY (ARRAY[?])", 
                                   text_words.map { |word| "%#{word}%" })
                             .limit(1)
        
        return pool if matches.any?
      end
      
      nil  # No pool detected
    end
    
    def self.format_bridge_results(bridge_items, pool1, pool2, entity1, entity2, top_k)
      bridges = []
      
      # Take top_k results
      bridge_items.first(top_k).each do |item|
        # Build path string showing the bridge
        path = build_bridge_path(item, pool1, pool2, entity1, entity2)
        
        # Calculate bridge score based on entity connections
        bridge_score = calculate_normalized_bridge_score(item)
        
        # Determine pools hit by this item
        pools_hit = []
        pools_hit << pool1 if pool1 && item[:entities][pool1]&.any?
        pools_hit << pool2 if pool2 && item[:entities][pool2]&.any?
        
        # Add additional pools if this item has entities in other pools
        additional_pools = get_additional_pools_for_item(item[:id])
        pools_hit.concat(additional_pools).uniq!
        
        bridges << {
          id: item[:id],
          title: item[:name] || "Untitled",
          pools_hit: pools_hit,
          bridge_score: bridge_score,
          path: path
        }
      end
      
      bridges
    end
    
    def self.build_bridge_path(item, pool1, pool2, entity1, entity2)
      path_elements = []
      
      # Add pool1 element
      if pool1
        pool1_entities = item[:entities][pool1] || []
        if entity1 && pool1_entities.include?(entity1)
          path_elements << "#{pool1.capitalize}(#{entity1})"
        elsif pool1_entities.any?
          path_elements << "#{pool1.capitalize}(#{pool1_entities.first})"
        else
          path_elements << "#{pool1.capitalize}(?)"
        end
      end
      
      # Add bridge item
      path_elements << "#{item[:name] || 'Item'}"
      
      # Add pool2 element
      if pool2
        pool2_entities = item[:entities][pool2] || []
        if entity2 && pool2_entities.include?(entity2)
          path_elements << "#{pool2.capitalize}(#{entity2})"
        elsif pool2_entities.any?
          path_elements << "#{pool2.capitalize}(#{pool2_entities.first})"
        else
          path_elements << "#{pool2.capitalize}(?)"
        end
      end
      
      path_elements.join(" → ")
    end
    
    def self.calculate_normalized_bridge_score(item)
      # Normalize bridge strength to 0-1 scale
      strength = item[:bridge_strength] || 0
      
      # Score based on number of connecting entities
      base_score = [strength / 10.0, 1.0].min
      
      # Bonus for items with entities in multiple pools
      pool_bonus = item[:entities]&.keys&.count || 0
      pool_bonus = [pool_bonus * 0.1, 0.3].min
      
      [(base_score + pool_bonus).round(2), 1.0].min
    end
    
    def self.get_additional_pools_for_item(item_id)
      return [] unless item_id
      
      # Get all pool entities for this item
      SearchEntity
        .joins(:searchable_item)
        .where(searchable_items: { id: item_id })
        .where("entity_type LIKE 'pool_%'")
        .pluck(:entity_type)
        .map { |et| et.sub('pool_', '') }
        .uniq
    end
    
    def self.find_bridge_entities_postgres(pool1, pool2)
      # Find entities that appear in both pools using PostgreSQL
      pool1_type = "pool_#{pool1}"
      pool2_type = "pool_#{pool2}"
      
      bridge_entities = SearchEntity
        .select('entity_value, COUNT(*) as occurrence_count')
        .where(entity_type: [pool1_type, pool2_type])
        .group(:entity_value)
        .having('COUNT(DISTINCT entity_type) = 2') # Must appear in both pools
        .order('occurrence_count DESC')
        .limit(20)
        .map do |entity|
          {
            name: entity.entity_value,
            total_occurrences: entity.occurrence_count,
            bridge_strength: calculate_bridge_strength(entity.occurrence_count)
          }
        end
      
      bridge_entities
    end
    
    def self.find_bridge_items_postgres(pool1, pool2)
      # Find items that have entities in both pools using PostgreSQL
      pool1_type = "pool_#{pool1}"
      pool2_type = "pool_#{pool2}"
      
      # Get items that have entities in both pools
      bridge_items = SearchableItem
        .joins(:search_entities)
        .where(search_entities: { entity_type: [pool1_type, pool2_type] })
        .group('searchable_items.id')
        .having('COUNT(DISTINCT search_entities.entity_type) = 2')
        .select('searchable_items.id, searchable_items.name, COUNT(*) as entity_count')
        .order('entity_count DESC')
        .limit(15)
        .map do |item|
          # Get the specific entities for this item
          pool1_entities = SearchEntity.where(searchable_item: item, entity_type: pool1_type).pluck(:entity_value)
          pool2_entities = SearchEntity.where(searchable_item: item, entity_type: pool2_type).pluck(:entity_value)
          
          {
            id: item.id.to_s,
            name: item.name,
            url: "https://offline.oknotok.com/item/#{item.id}",
            entities: {
              pool1 => pool1_entities,
              pool2 => pool2_entities
            },
            bridge_strength: pool1_entities.count + pool2_entities.count,
            bridge_type: "#{pool1}-#{pool2}"
          }
        end
      
      bridge_items
    end
    
    def self.find_bridge_entities_neo4j(service, pool1, pool2)
      bridge_entities = []
      
      service.with_session do |session|
        # Find entities that appear in both pools
        results = session.run(<<~CYPHER, pool1: "pool_#{pool1}", pool2: "pool_#{pool2}")
          MATCH (e1:BM_Entity {pool: $pool1})
          MATCH (e2:BM_Entity {pool: $pool2})
          WHERE e1.name = e2.name
          WITH e1.name as entity_name, 
               e1.occurrence_count + e2.occurrence_count as total_occurrences
          ORDER BY total_occurrences DESC
          LIMIT 20
          RETURN entity_name, total_occurrences
        CYPHER
        
        bridge_entities = results.map do |result|
          {
            name: result[:entity_name],
            total_occurrences: result[:total_occurrences],
            bridge_strength: calculate_bridge_strength(result[:total_occurrences])
          }
        end
      end
      
      bridge_entities
    end
    
    def self.determine_overall_bridge_strength(bridge_entities, bridge_items)
      if bridge_entities.empty? && bridge_items.empty?
        "none"
      elsif bridge_entities.count >= 5 || bridge_items.count >= 10
        "strong"
      elsif bridge_entities.count >= 2 || bridge_items.count >= 5
        "moderate"
      else
        "weak"
      end
    end
    
    def self.find_bridge_items_neo4j(service, pool1, pool2)
      bridge_items = []
      
      service.with_session do |session|
        # Find items that have entities in both pools
        results = session.run(<<~CYPHER, pool1: "pool_#{pool1}", pool2: "pool_#{pool2}")
          MATCH (item:BM_Item)-[:BM_HAS_ENTITY]->(e1:BM_Entity {pool: $pool1})
          MATCH (item)-[:BM_HAS_ENTITY]->(e2:BM_Entity {pool: $pool2})
          WITH item, 
               COLLECT(DISTINCT e1.name) as pool1_entities,
               COLLECT(DISTINCT e2.name) as pool2_entities,
               COUNT(DISTINCT e1) + COUNT(DISTINCT e2) as entity_count
          ORDER BY entity_count DESC
          LIMIT 15
          RETURN item.uid as item_uid, item.name as item_name,
                 pool1_entities, pool2_entities, entity_count
        CYPHER
        
        bridge_items = results.map do |result|
          # Extract item ID from UID (format: "camp-2025-12345")
          item_id = result[:item_uid]&.split('-')&.last
          
          {
            id: item_id,
            name: result[:item_name],
            url: item_id ? "https://offline.oknotok.com/item/#{item_id}" : nil,
            entities: {
              pool1 => result[:pool1_entities] || [],
              pool2 => result[:pool2_entities] || []
            },
            bridge_strength: result[:entity_count],
            bridge_type: "#{pool1}-#{pool2}"
          }
        end
      end
      
      bridge_items
    end
    
    def self.analyze_semantic_connections(pool1, pool2)
      # Analyze the conceptual relationship between pools
      pool_descriptions = {
        "manifest" => "Physical structures, tangible creations, built environment",
        "experience" => "Sensory memories, transformations, lived experiences", 
        "relational" => "Social connections, community bonds, relationships",
        "idea" => "Philosophy, concepts, principles, beliefs",
        "practical" => "How-to knowledge, techniques, skills, methods",
        "evolutionary" => "Changes over time, history, development, growth",
        "emanation" => "Spiritual insights, emergence, transcendence, mystery"
      }
      
      {
        pool1_nature: pool_descriptions[pool1] || "Unknown pool",
        pool2_nature: pool_descriptions[pool2] || "Unknown pool",
        connection_theme: determine_connection_theme(pool1, pool2),
        examples: get_connection_examples(pool1, pool2)
      }
    end
    
    def self.determine_relationship_type(pool1, pool2)
      relationships = {
        ["manifest", "experience"] => "Physical-to-Experiential",
        ["manifest", "relational"] => "Structure-to-Community", 
        ["experience", "idea"] => "Lived-to-Conceptual",
        ["idea", "practical"] => "Theory-to-Practice",
        ["relational", "emanation"] => "Social-to-Spiritual",
        ["practical", "evolutionary"] => "Skills-to-Adaptation"
      }
      
      key = [pool1, pool2].sort
      relationships[key] || relationships[[pool2, pool1]] || "Cross-Domain"
    end
    
    def self.determine_connection_theme(pool1, pool2)
      themes = {
        ["manifest", "experience"] => "How structures create experiences",
        ["manifest", "relational"] => "How spaces foster community",
        ["experience", "idea"] => "How experiences embody concepts", 
        ["idea", "practical"] => "How principles become practice",
        ["relational", "emanation"] => "How community enables transcendence",
        ["practical", "evolutionary"] => "How skills drive evolution"
      }
      
      key = [pool1, pool2].sort
      themes[key] || themes[[pool2, pool1]] || "Interdisciplinary connections"
    end
    
    def self.get_connection_examples(pool1, pool2)
      examples = {
        ["manifest", "experience"] => ["Art cars creating mobile experiences", "Temples facilitating spiritual journeys"],
        ["manifest", "relational"] => ["Camp kitchens fostering sharing", "Common areas building community"],
        ["experience", "idea"] => ["Burn ceremonies expressing impermanence", "Gift economy practicing generosity"],
        ["idea", "practical"] => ["Radical self-reliance teaching skills", "Leave No Trace protecting environment"],
        ["relational", "emanation"] => ["Sacred circles creating connection", "Community rituals enabling transcendence"]
      }
      
      key = [pool1, pool2].sort
      examples[key] || examples[[pool2, pool1]] || ["Cross-domain innovations", "Hybrid approaches"]
    end
    
    def self.calculate_bridge_strength(occurrences)
      case occurrences
      when 0..5 then "weak"
      when 6..15 then "moderate" 
      when 16..30 then "strong"
      else "very_strong"
      end
    end
    
    def self.generate_insights(pool1, pool2, bridge_entities, bridge_items)
      insights = []
      
      if bridge_entities.any?
        top_entity = bridge_entities.first
        insights << "The concept '#{top_entity[:name]}' strongly bridges #{pool1} and #{pool2} domains (#{top_entity[:total_occurrences]} occurrences)"
      end
      
      if bridge_items.any?
        insights << "Found #{bridge_items.count} items that actively connect #{pool1} and #{pool2} pools"
        
        strong_bridges = bridge_items.select { |item| item[:bridge_strength] >= 6 }
        insights << "#{strong_bridges.count} items show strong cross-pool integration" if strong_bridges.any?
      end
      
      relationship_type = determine_relationship_type(pool1, pool2)
      insights << "This represents a #{relationship_type} connection in Burning Man culture"
      
      insights
    end
  end
end