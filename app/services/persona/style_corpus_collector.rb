# frozen_string_literal: true

module Persona
  class StyleCorpusCollector
    # Collect relevant corpus items for persona style analysis
    # Focuses on authored content, quotes, and strong associations
    
    def self.call(persona_id:, era: nil, require_rights: 'public')
      new(persona_id: persona_id, era: era, require_rights: require_rights).collect
    end
    
    def initialize(persona_id:, era: nil, require_rights: 'public')
      @persona_id = persona_id
      @era = era
      @require_rights = require_rights
      @persona_label = extract_label_from_id(persona_id)
    end
    
    def collect
      start_time = Time.current
      
      corpus_items = []
      
      # Strategy 1: Direct semantic search for persona name
      corpus_items.concat(collect_via_semantic_search)
      
      # Strategy 2: Find items with high entity association
      corpus_items.concat(collect_via_entity_association)
      
      # Strategy 3: Focus on authored content (Idea + Manifest pools)
      corpus_items.concat(collect_authored_content)
      
      # Strategy 4: Experience pool items (quotes, stories about the person)
      corpus_items.concat(collect_experience_content)
      
      # Strategy 5: Emanation pool (philosophical writings, principles)
      corpus_items.concat(collect_emanation_content)
      
      # Deduplicate and filter
      unique_items = deduplicate_and_score(corpus_items)
      filtered_items = apply_rights_filter(unique_items)
      final_items = apply_era_filter(filtered_items)
      
      execution_time = Time.current - start_time
      
      {
        ok: true,
        corpus_items: final_items,
        total_items: final_items.length,
        strategies_used: count_strategies(corpus_items),
        execution_time: execution_time.round(3),
        coverage_pools: analyze_pool_coverage(final_items),
        era_coverage: analyze_era_coverage(final_items)
      }
    rescue => e
      Rails.logger.error "StyleCorpusCollector error: #{e.message}"
      {
        ok: false,
        error: "Corpus collection failed: #{e.message}",
        corpus_items: []
      }
    end
    
    private
    
    def extract_label_from_id(persona_id)
      # Extract readable label from persona_id like "person:larry_harvey"
      persona_id.split(':', 2).last.humanize.titleize
    end
    
    def collect_via_semantic_search
      Rails.logger.info "Collecting corpus via semantic search for #{@persona_label}"
      
      search_result = ::Mcp::SearchTool.call(
        query: @persona_label,
        top_k: 15,
        diversify_by_pool: true,
        include_trace: false
      )
      
      return [] unless search_result[:items]
      
      search_result[:items].map do |item|
        corpus_item_from_search(item, strategy: 'semantic_search')
      end
    end
    
    def collect_via_entity_association
      Rails.logger.info "Collecting corpus via entity association for #{@persona_label}"
      
      # Find items that have this person as an entity
      associated_items = SearchableItem
        .joins(:search_entities)
        .where(search_entities: { 
          entity_type: 'person', 
          entity_value: [@persona_label, @persona_label.downcase]
        })
        .limit(20)
      
      associated_items.map do |item|
        corpus_item_from_model(item, strategy: 'entity_association')
      end
    end
    
    def collect_authored_content
      Rails.logger.info "Collecting authored content for #{@persona_label}"
      
      # Look for content in Idea and Manifest pools with strong person association
      authored_items = SearchableItem
        .joins(:search_entities)
        .where(search_entities: { entity_type: 'person' })
        .where('search_entities.entity_value ILIKE ?', "%#{@persona_label}%")
        .where(item_type: ['philosophical_text', 'principle', 'manifesto', 'speech'])
        .limit(10)
      
      authored_items.map do |item|
        corpus_item_from_model(item, strategy: 'authored_content')
      end
    end
    
    def collect_experience_content
      Rails.logger.info "Collecting experience content for #{@persona_label}"
      
      # Find Experience pool items (stories, quotes, interviews)
      experience_items = SearchableItem
        .joins(:search_entities)
        .where(search_entities: { 
          entity_type: ['person', 'pool_experience'],
          entity_value: [@persona_label, @persona_label.downcase]
        })
        .where('description ILIKE ? OR name ILIKE ?', "%#{@persona_label}%", "%#{@persona_label}%")
        .limit(15)
      
      experience_items.map do |item|
        corpus_item_from_model(item, strategy: 'experience_content')
      end
    end
    
    def collect_emanation_content
      Rails.logger.info "Collecting emanation content for #{@persona_label}"
      
      # Find philosophical or principle-based content
      emanation_items = SearchableItem
        .joins(:search_entities)
        .where(search_entities: { entity_type: 'pool_emanation' })
        .where('description ILIKE ? OR name ILIKE ?', "%#{@persona_label}%", "%#{@persona_label}%")
        .limit(10)
      
      emanation_items.map do |item|
        corpus_item_from_model(item, strategy: 'emanation_content')
      end
    end
    
    def corpus_item_from_search(search_item, strategy:)
      {
        id: search_item[:id],
        title: search_item[:title],
        content: search_item[:summary],
        year: extract_year_from_search_item(search_item),
        item_type: 'unknown',
        pools_hit: search_item[:pools_hit] || [],
        score: search_item[:score] || 0.0,
        strategy: strategy,
        rights: search_item[:rights] || default_rights,
        provenance: search_item[:provenance] || []
      }
    end
    
    def corpus_item_from_model(item, strategy:)
      {
        id: item.id.to_s,
        title: item.name,
        content: item.description || '',
        year: item.year,
        item_type: item.item_type,
        pools_hit: get_pools_for_item(item.id),
        score: calculate_relevance_score(item, strategy),
        strategy: strategy,
        rights: get_item_rights(item.id),
        provenance: get_item_provenance(item.id)
      }
    end
    
    def extract_year_from_search_item(search_item)
      # Try to extract year from title or use current year as fallback
      year_match = search_item[:title]&.match(/(19\d{2}|20\d{2})/)
      year_match ? year_match[1].to_i : 2024
    end
    
    def get_pools_for_item(item_id)
      SearchEntity
        .joins(:searchable_item)
        .where(searchable_items: { id: item_id })
        .where("entity_type LIKE 'pool_%'")
        .pluck(:entity_type)
        .map { |type| type.sub('pool_', '') }
        .uniq
    end
    
    def calculate_relevance_score(item, strategy)
      base_score = case strategy
                  when 'authored_content' then 0.9
                  when 'emanation_content' then 0.8
                  when 'entity_association' then 0.7
                  when 'experience_content' then 0.6
                  when 'semantic_search' then 0.5
                  else 0.3
                  end
      
      # Boost score based on content length (more content = better for style analysis)
      content_length = item.description&.length || 0
      length_bonus = case content_length
                    when 0..100 then 0.0
                    when 101..500 then 0.1
                    when 501..1500 then 0.2
                    else 0.3
                    end
      
      (base_score + length_bonus).round(2)
    end
    
    def deduplicate_and_score(corpus_items)
      # Remove duplicates by ID and keep highest scoring version
      items_by_id = {}
      
      corpus_items.each do |item|
        item_id = item[:id]
        if !items_by_id[item_id] || items_by_id[item_id][:score] < item[:score]
          items_by_id[item_id] = item
        end
      end
      
      items_by_id.values.sort_by { |item| -item[:score] }
    end
    
    def apply_rights_filter(items)
      return items if @require_rights == 'any'
      
      items.select do |item|
        rights = item[:rights]
        case @require_rights
        when 'public'
          rights[:visibility] == 'public'
        when 'internal'
          ['public', 'internal'].include?(rights[:visibility])
        else
          true
        end
      end
    end
    
    def apply_era_filter(items)
      return items unless @era
      
      era_range = parse_era(@era)
      return items unless era_range
      
      items.select do |item|
        item_year = item[:year] || 2024
        era_range.cover?(item_year)
      end
    end
    
    def parse_era(era_string)
      # Parse era strings like "2000-2016", "2010", "early_2000s"
      case era_string
      when /^(\d{4})-(\d{4})$/
        ($1.to_i)..($2.to_i)
      when /^(\d{4})$/
        year = $1.to_i
        (year)..(year)
      when /early_(\d{4})s/
        decade_start = $1.to_i
        (decade_start)..(decade_start + 3)
      when /late_(\d{4})s/
        decade_start = $1.to_i
        (decade_start + 6)..(decade_start + 9)
      else
        nil
      end
    end
    
    def count_strategies(corpus_items)
      corpus_items.group_by { |item| item[:strategy] }
                  .transform_values(&:length)
    end
    
    def analyze_pool_coverage(items)
      all_pools = items.flat_map { |item| item[:pools_hit] }.uniq
      pool_counts = items.flat_map { |item| item[:pools_hit] }
                         .group_by(&:itself)
                         .transform_values(&:length)
      
      {
        pools_covered: all_pools,
        pool_distribution: pool_counts
      }
    end
    
    def analyze_era_coverage(items)
      years = items.map { |item| item[:year] }.compact.sort
      return { years: [], span: 0 } if years.empty?
      
      {
        years: years.uniq,
        span: years.max - years.min,
        earliest: years.min,
        latest: years.max
      }
    end
    
    def get_item_rights(item_id)
      # Default rights - in production this would come from database
      {
        license: "CC-BY",
        consent: "public",
        visibility: "public",
        attribution_required: true
      }
    end
    
    def get_item_provenance(item_id)
      # Default provenance - in production this would come from database
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
    
    def default_rights
      {
        license: "CC-BY",
        consent: "public",
        visibility: "public",
        attribution_required: true
      }
    end
  end
end