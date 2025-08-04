# frozen_string_literal: true

module Mcp
  class FetchTool
    VALID_POOLS = %w[idea manifest experience relational evolutionary practical emanation].freeze
    
    def self.call(id:, include_relations: true, relation_depth: 1, pools: nil, as_of: nil)
      # Validate inputs
      relation_depth = [relation_depth, 3].min  # Max depth of 3
      return validation_error("invalid_pool", id) if pools&.any? { |p| !VALID_POOLS.include?(p) }
      
      item = SearchableItem.find_by(id: id)
      
      unless item
        return {
          error: "Item not found",
          id: id
        }
      end
      
      # Get all entities for this item
      pool_entities = get_pool_entities(item.id, pools)
      basic_entities = get_basic_entities(item.id)
      
      # Get relationships if requested
      relations = []
      if include_relations
        relations = get_item_relations(item.id, relation_depth, pools)
      end
      
      # Get timeline/version history
      timeline = get_item_timeline(item.id, as_of)
      
      # Get rights and provenance
      rights = get_item_rights(item.id)
      provenance = get_item_provenance(item.id)
      
      # Build fields object
      fields = {
        type: item.item_type,
        year: item.year,
        coords: extract_coordinates(item.location_string),
        location_string: item.location_string,
        camp_name: extract_camp_name(item),
        art_category: extract_art_category(item),
        event_type: item.event_type
      }.compact
      
      # Get current pool list
      pools_list = pool_entities.keys.map { |k| k.sub('pool_', '') }
      
      # Format according to Tool Contract v1.1
      {
        id: item.id.to_s,
        title: item.name || "Untitled",
        body: format_body_content(item),
        fields: fields,
        pools: pools_list,
        relations: relations,
        timeline: timeline,
        provenance: provenance,
        rights: rights,
        versions: get_item_versions(item.id)
      }
    rescue => e
      Rails.logger.error "FetchTool error: #{e.message}"
      {
        error: "Fetch failed: #{e.message}",
        id: id
      }
    end
    
    private
    
    def self.validation_error(message, id)
      {
        error: message,
        id: id
      }
    end
    
    def self.get_pool_entities(item_id, pool_filter = nil)
      query = SearchEntity
        .joins(:searchable_item)
        .where(searchable_items: { id: item_id })
        .where("entity_type LIKE 'pool_%'")
        
      # Apply pool filter if specified
      if pool_filter&.any?
        pool_types = pool_filter.map { |p| "pool_#{p}" }
        query = query.where(entity_type: pool_types)
      end
      
      query.group_by(&:entity_type)
        .transform_values { |entities| entities.map(&:entity_value).uniq }
    end
    
    def self.get_basic_entities(item_id)
      basic_types = %w[location activity theme time person item_type contact organizational service schedule requirement]
      
      SearchEntity
        .joins(:searchable_item)
        .where(searchable_items: { id: item_id })
        .where(entity_type: basic_types)
        .group_by(&:entity_type)
        .transform_values { |entities| entities.map(&:entity_value).uniq }
    end
    
    def self.get_item_relations(item_id, depth, pool_filter)
      # Get related items through shared entities
      relations = []
      
      # Find items that share entities with this item
      shared_entities = SearchEntity
        .joins(:searchable_item)
        .where(searchable_items: { id: item_id })
        .joins("JOIN search_entities se2 ON se2.entity_type = search_entities.entity_type AND se2.entity_value = search_entities.entity_value")
        .joins("JOIN searchable_items si2 ON si2.id = se2.searchable_item_id")
        .where("se2.searchable_item_id != ?", item_id)
        .select("DISTINCT si2.id, si2.name, search_entities.entity_type, search_entities.entity_value, si2.created_at")
        .limit(20)
      
      shared_entities.each do |relation|
        pool = relation.entity_type.sub('pool_', '') if relation.entity_type.start_with?('pool_')
        
        # Skip if pool filter specified and this relation doesn't match
        next if pool_filter&.any? && pool && !pool_filter.include?(pool)
        
        relations << {
          type: "shares_entity",
          to_id: relation.id.to_s,
          to_title: relation.name || "Untitled",
          pool: pool,
          since: relation.created_at&.iso8601,
          until: nil,
          shared_entity: relation.entity_value
        }
      end
      
      relations.first(10)  # Limit to prevent overwhelming responses
    end
    
    def self.get_item_timeline(item_id, as_of)
      # Simple timeline - in production this would track actual version history
      item = SearchableItem.find_by(id: item_id)
      return [] unless item
      
      timeline = []
      
      # Add creation event
      timeline << {
        version: "v1",
        at: item.created_at&.iso8601 || "#{item.year || 2024}-01-01T00:00:00Z",
        note: "Initial import from Burning Man #{item.year || 2024} data"
      }
      
      # Add update event if updated
      if item.updated_at && item.updated_at != item.created_at
        timeline << {
          version: "v2",
          at: item.updated_at.iso8601,
          note: "Entity extraction and enliteracy processing"
        }
      end
      
      # Filter by as_of if specified
      if as_of
        cutoff = Time.parse(as_of)
        timeline = timeline.select { |t| Time.parse(t[:at]) <= cutoff }
      end
      
      timeline
    end
    
    def self.get_item_rights(item_id)
      # Default rights - in production this would come from database
      {
        license: "CC-BY",
        consent: "public",
        visibility: "public",
        attribution_required: true
      }
    end
    
    def self.get_item_provenance(item_id)
      item = SearchableItem.find_by(id: item_id)
      source_year = item&.year || 2024
      
      [{
        source_id: "burning_man_#{source_year}",
        citation: "Burning Man #{source_year} Official Data",
        collected_by: "OK-OFFLINE Team",
        collected_at: "#{source_year}-01-01T00:00:00Z",
        method: "automated_import"
      }]
    end
    
    def self.get_item_versions(item_id)
      # Simple versioning - in production would track actual versions
      item = SearchableItem.find_by(id: item_id)
      return [] unless item
      
      versions = [{
        id: "v1",
        at: item.created_at&.iso8601 || "#{item.year || 2024}-01-01T00:00:00Z"
      }]
      
      if item.updated_at && item.updated_at != item.created_at
        versions << {
          id: "v2",
          at: item.updated_at.iso8601
        }
      end
      
      versions
    end
    
    def self.extract_coordinates(location_string)
      return nil unless location_string
      
      # Try to extract lat/lon if present in location string
      # This is a simple implementation - production would have better parsing
      coord_match = location_string.match(/(-?\d+\.\d+),\s*(-?\d+\.\d+)/)
      if coord_match
        [coord_match[1].to_f, coord_match[2].to_f]
      else
        nil
      end
    end
    
    def self.extract_camp_name(item)
      case item.item_type
      when 'camp'
        item.name
      when 'art', 'event'
        # Check if there's camp info in metadata
        item.metadata&.dig('camp') || item.metadata&.dig('camp_name')
      else
        nil
      end
    end
    
    def self.extract_art_category(item)
      case item.item_type
      when 'art'
        item.metadata&.dig('category') || item.metadata&.dig('art_category')
      else
        nil
      end
    end

    def self.format_body_content(item)
      # Format item content as markdown
      content = []
      
      content << "# #{item.name}" if item.name
      content << "" # blank line
      
      if item.description.present?
        content << item.description
        content << ""
      end
      
      # Add structured information
      if item.item_type
        content << "**Type:** #{item.item_type.humanize}"
      end
      
      if item.year
        content << "**Year:** #{item.year}"
      end
      
      if item.location_string
        content << "**Location:** #{item.location_string}"
      end
      
      content.join("\n")
    end
  end
end