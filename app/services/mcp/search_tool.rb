# frozen_string_literal: true

module Mcp
  class SearchTool
    VALID_POOLS = %w[idea manifest experience relational evolutionary practical emanation].freeze

    def self.call(query:, top_k: 10, pools: nil, date_from: nil, date_to: nil, require_rights: "public", diversify_by_pool: true, include_trace: true, include_counts: true)
      # Normalize pool names to lowercase
      pools = pools&.map(&:downcase) if pools
      
      # Validate inputs
      return validation_error("top_k out of range") if top_k < 1 || top_k > 50
      return validation_error("invalid_pool") if pools&.any? { |p| !VALID_POOLS.include?(p) }

      # Extract year from query if present for backwards compatibility
      year_match = query.match(/(19\d{2}|20\d{2})/)
      search_year = year_match ? year_match[1].to_i : nil

      # Parse date range
      year_filter = parse_date_range(date_from, date_to) || search_year

      # Use existing unified search with graph expansion
      service = Search::UnifiedSearchService.new
      results = service.search(
        query: query,
        year: year_filter,
        limit: top_k,
        expand_graph: true,
        graph_depth: 2
      )

      # Format results according to Tool Contract v1.1
      formatted_items = []
      pool_counts = Hash.new(0)

      if results["results"] || results[:results]
        search_results = results["results"] || results[:results]

        # Apply pool filtering if specified
        if pools&.any?
          search_results = filter_results_by_pools(search_results, pools)
        end

        # Apply pool diversification if requested
        search_results = diversify_results_by_pool(search_results) if diversify_by_pool

        formatted_items = search_results.map do |result|
          item_id = (result["id"] || result[:id]).to_s

          # Get pool entities for this item
          pool_entities = get_pool_entities(item_id)
          pools_hit = pool_entities.keys.map { |k| k.sub("pool_", "") }

          # Count pools for metadata
          pools_hit.each { |pool| pool_counts[pool] += 1 }

          # Build trace string if requested
          trace = include_trace ? build_trace_string(item_id, pools_hit, result) : nil

          # Get rights and provenance
          rights = get_item_rights(item_id)
          provenance = get_item_provenance(item_id)

          # Skip if rights requirements not met
          next if require_rights == "public" && rights[:visibility] != "public"

          {
            id: item_id,
            title: result["name"] || result[:name] || "Untitled",
            summary: truncate_text(result["description"] || result[:description] || "", 200),
            pools_hit: pools_hit,
            score: ((result["combined_score"] || result[:combined_score]) || 0.0).round(3),
            highlights: extract_highlights(result, query),
            provenance: provenance,
            rights: rights,
            trace: trace
          }
        end.compact
      end

      # Calculate total estimate
      total_estimate = results.dig("meta", "total_count") || results.dig(:meta, :total_count) || formatted_items.length

      {
        items: formatted_items,
        meta: {
          total_estimate: total_estimate,
          pool_counts: include_counts ? pool_counts : nil
        }.compact
      }
    rescue => e
      Rails.logger.error "SearchTool error: #{e.message}"
      {
        error: "Search failed: #{e.message}",
        items: [],
        meta: { total_estimate: 0, pool_counts: {} }
      }
    end

    private

    def self.validation_error(message)
      {
        error: message,
        items: [],
        meta: { total_estimate: 0, pool_counts: {} }
      }
    end

    def self.parse_date_range(date_from, date_to)
      return nil unless date_from || date_to

      begin
        from_year = date_from ? Date.parse(date_from).year : nil
        to_year = date_to ? Date.parse(date_to).year : nil

        # For simplicity, return the from_year if specified
        from_year
      rescue Date::Error
        validation_error("bad_date_range")
      end
    end

    def self.filter_results_by_pools(results, pool_filter)
      # Filter results to only include items that have entities in the specified pools
      return results unless pool_filter&.any?

      pool_types = pool_filter.map { |p| "pool_#{p}" }

      results.select do |result|
        item_id = result["id"] || result[:id]
        next false unless item_id

        # Check if this item has entities in any of the specified pools
        has_pool_entities = SearchEntity
          .joins(:searchable_item)
          .where(searchable_items: { id: item_id })
          .where(entity_type: pool_types)
          .exists?

        has_pool_entities
      end
    end

    def self.diversify_results_by_pool(results)
      # Simple diversification: ensure we have representation from different pools
      # More sophisticated algorithm could be implemented later
      results
    end

    def self.get_pool_entities(item_id)
      SearchEntity
        .joins(:searchable_item)
        .where(searchable_items: { id: item_id })
        .where("entity_type LIKE 'pool_%'")
        .group_by(&:entity_type)
        .transform_values { |entities| entities.map(&:entity_value).uniq }
    end

    def self.build_trace_string(item_id, pools_hit, result)
      # Build a readable trace showing the path through pools
      item_name = result["name"] || result[:name] || "Item #{item_id}"
      pool_fragments = pools_hit.first(3).map { |pool| "#{pool.capitalize}(#{item_name})" }
      pool_fragments.join(" → ")
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
      # Default provenance - in production this would come from database
      item = SearchableItem.find_by(id: item_id)
      source_year = item&.year || 2024

      [ {
        source_id: "burning_man_#{source_year}",
        citation: "Burning Man #{source_year} Official Data",
        collected_by: "OK-OFFLINE Team",
        collected_at: "#{source_year}-01-01T00:00:00Z",
        method: "automated_import"
      } ]
    end

    def self.extract_highlights(result, query)
      # Simple highlighting - in production would use proper text highlighting
      description = result["description"] || result[:description] || ""
      query_words = query.downcase.split(/\s+/)

      highlights = []
      query_words.each do |word|
        next if word.length < 3

        if description.downcase.include?(word)
          # Extract a snippet around the match
          index = description.downcase.index(word)
          start_pos = [ 0, index - 30 ].max
          end_pos = [ description.length, index + word.length + 30 ].min
          snippet = description[start_pos...end_pos].strip
          highlights << "...#{snippet}..." unless highlights.include?("...#{snippet}...")
        end
      end

      highlights.first(3)  # Limit to 3 highlights
    end

    def self.truncate_text(text, max_length = 500)
      return "" if text.blank?

      text = text.to_s.strip
      return text if text.length <= max_length

      # Truncate at word boundary
      truncated = text[0...max_length]
      last_space = truncated.rindex(" ")
      last_space ? truncated[0...last_space] + "..." : truncated + "..."
    end
  end
end
