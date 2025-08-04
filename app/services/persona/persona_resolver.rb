# frozen_string_literal: true

module Persona
  class PersonaResolver
    def self.call(persona_input)
      new(persona_input).resolve
    end
    
    def initialize(persona_input)
      @persona_input = persona_input.to_s.strip
    end
    
    def resolve
      return error("Empty persona input") if @persona_input.blank?
      
      # Try direct ID lookup first (format: "type:id" like "person:larry_harvey")
      if direct_id_match?
        return resolve_direct_id
      end
      
      # Try exact entity value match
      exact_match = find_exact_entity_match
      return exact_match if exact_match[:ok]
      
      # Try fuzzy matching with analyze_pools
      fuzzy_match = resolve_via_analyze_pools
      return fuzzy_match if fuzzy_match[:ok]
      
      # Last resort: search for person entities
      search_match = resolve_via_search
      return search_match if search_match[:ok]
      
      error("Persona not found: #{@persona_input}")
    end
    
    private
    
    def direct_id_match?
      @persona_input.match?(/^(person|artist|founder|leader):[a-z_]+$/)
    end
    
    def resolve_direct_id
      # Extract type and identifier
      type, identifier = @persona_input.split(':', 2)
      
      # Look for entities with this exact value pattern
      entity = SearchEntity
        .where(entity_type: 'person')
        .where('entity_value ILIKE ?', "%#{identifier.humanize}%")
        .first
      
      if entity
        success(
          persona_id: @persona_input,
          persona_label: entity.entity_value.titleize
        )
      else
        error("Direct ID not found: #{@persona_input}")
      end
    end
    
    def find_exact_entity_match
      # Look for exact matches in person entities
      entity = SearchEntity
        .where(entity_type: 'person')
        .where('LOWER(entity_value) = LOWER(?)', @persona_input)
        .first
      
      if entity
        success(
          persona_id: generate_persona_id(entity.entity_value),
          persona_label: entity.entity_value.titleize
        )
      else
        error("No exact match found")
      end
    end
    
    def resolve_via_analyze_pools
      # Use existing analyze_pools tool to find linked entities
      begin
        result = ::Mcp::AnalyzePoolsTool.call(
          text: @persona_input,
          mode: 'link',
          link_threshold: 0.7
        )
        
        # Look for person entities in the response
        if result.dig(:pools, :idea, :entities)&.any?
          person_entities = result[:pools][:idea][:entities].select do |entity|
            entity[:type] == 'person'
          end
          
          if person_entities.any?
            best_match = person_entities.max_by { |e| e[:confidence] || 0.0 }
            
            success(
              persona_id: generate_persona_id(best_match[:value]),
              persona_label: best_match[:value].titleize
            )
          else
            error("No person entities found in analysis")
          end
        else
          error("No entities found in analysis")
        end
      rescue => e
        Rails.logger.error "PersonaResolver analyze_pools error: #{e.message}"
        error("Analysis failed: #{e.message}")
      end
    end
    
    def resolve_via_search
      # Search for items related to this person
      begin
        search_result = ::Mcp::SearchTool.call(
          query: @persona_input,
          top_k: 5,
          pools: ['idea'],
          diversify_by_pool: false
        )
        
        if search_result[:items]&.any?
          # Look through search results for person entities
          search_result[:items].each do |item|
            item_entities = get_person_entities_for_item(item[:id])
            
            person_match = item_entities.find do |entity|
              entity.downcase.include?(@persona_input.downcase) ||
              @persona_input.downcase.include?(entity.downcase)
            end
            
            if person_match
              return success(
                persona_id: generate_persona_id(person_match),
                persona_label: person_match.titleize
              )
            end
          end
        end
        
        error("No person found in search results")
      rescue => e
        Rails.logger.error "PersonaResolver search error: #{e.message}"
        error("Search failed: #{e.message}")
      end
    end
    
    def get_person_entities_for_item(item_id)
      SearchEntity
        .joins(:searchable_item)
        .where(searchable_items: { id: item_id })
        .where(entity_type: 'person')
        .pluck(:entity_value)
    end
    
    def generate_persona_id(entity_value)
      # Convert entity value to standardized persona ID
      normalized = entity_value.downcase
                              .gsub(/[^a-z0-9\s]/, '')
                              .gsub(/\s+/, '_')
      
      "person:#{normalized}"
    end
    
    def success(persona_id:, persona_label:)
      {
        ok: true,
        persona_id: persona_id,
        persona_label: persona_label
      }
    end
    
    def error(message)
      {
        ok: false,
        error: message,
        persona_id: nil,
        persona_label: nil
      }
    end
  end
end