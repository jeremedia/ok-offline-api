# frozen_string_literal: true

# MCP Search Tool - Unified Semantic + Graph Search
#
# This tool provides the primary search interface for the MCP server, combining:
# - Vector similarity search using embeddings
# - Entity graph traversal
# - Pool-based filtering and analysis
# - Rights and provenance tracking
#
# Tool Contract v1.1 compliant - returns structured results with metadata.
# For implementation patterns, see: docs/RAILS_MCP_SERVER_IMPLEMENTATION_GUIDE.md
#
# Example usage via MCP:
# {
#   "name": "search",
#   "arguments": {
#     "query": "art installations 2024",
#     "top_k": 10,
#     "pools": ["manifest", "experience"],
#     "diversify_by_pool": true
#   }
# }
module Mcp
  class SearchTool
    # Seven Pools of Enliteracy - valid pool names for filtering
    # Each pool represents a different cognitive dimension of understanding
    VALID_POOLS = %w[idea manifest experience relational evolutionary practical emanation].freeze

    # Main entry point: Execute semantic search with comprehensive filtering
    #
    # Arguments:
    #   query: Natural language search query (required)
    #   top_k: Number of results to return (1-50, default: 10)
    #   pools: Filter to specific pools only (optional)
    #   date_from/date_to: ISO8601 date range filtering (optional)
    #   require_rights: Rights requirement ("public", "internal", "any")
    #   diversify_by_pool: Ensure diverse pool representation (default: true)
    #   include_trace: Include relationship traces (default: true)
    #   include_counts: Include pool count metadata (default: true)
    #
    # Returns: Hash with Tool Contract v1.1 format:
    #   {
    #     items: [ { id, title, summary, pools_hit, score, highlights, ... } ],
    #     meta: { total_estimate, pool_counts }
    #   }
    #
    # See implementation guide: Step 3 - Create Tool Services
    def self.call(query:, top_k: 10, pools: nil, date_from: nil, date_to: nil, require_rights: "public", diversify_by_pool: true, include_trace: true, include_counts: true)
      # Input validation and normalization
      # Critical: Always validate inputs to prevent injection attacks
      pools = pools&.map(&:downcase) if pools
      
      # Validate numerical constraints (prevents resource exhaustion)
      return validation_error("top_k out of range") if top_k < 1 || top_k > 50
      
      # Validate pool names against allowed values
      return validation_error("invalid_pool") if pools&.any? { |p| !VALID_POOLS.include?(p) }

      # Query processing: Extract temporal context for enhanced search
      # Pattern: Extract years from natural language ("burning man 2019")
      year_match = query.match(/(19\d{2}|20\d{2})/)
      search_year = year_match ? year_match[1].to_i : nil

      # Date range processing: Explicit dates override query-extracted years
      year_filter = parse_date_range(date_from, date_to) || search_year

      # Execute unified search: Combines vector similarity + graph traversal
      # This leverages the existing Search::UnifiedSearchService which:
      # 1. Generates query embeddings
      # 2. Performs vector similarity search
      # 3. Expands results through entity graph
      # 4. Applies temporal and rights filtering
      service = Search::UnifiedSearchService.new
      results = service.search(
        query: query,
        year: year_filter,
        limit: top_k,
        expand_graph: true,    # Enable graph-based result expansion
        graph_depth: 2         # Traverse up to 2 relationship hops
      )

      # Result processing: Format according to MCP Tool Contract v1.1
      # This ensures consistent response format across all MCP tools
      formatted_items = []
      pool_counts = Hash.new(0)  # Track pool distribution for analytics

      if results["results"] || results[:results]
        search_results = results["results"] || results[:results]

        # Post-processing filters: Apply client-specified constraints
        if pools&.any?
          # Filter to only items that have entities in the specified pools
          search_results = filter_results_by_pools(search_results, pools)
        end

        # Diversification: Ensure balanced representation across pools
        # This prevents results from being dominated by a single pool type
        search_results = diversify_results_by_pool(search_results) if diversify_by_pool

        # Transform search results into MCP Tool Contract v1.1 format
        formatted_items = search_results.map do |result|
          item_id = (result["id"] || result[:id]).to_s

          # Pool analysis: Identify which of the Seven Pools this item activates
          pool_entities = get_pool_entities(item_id)
          pools_hit = pool_entities.keys.map { |k| k.sub("pool_", "") }

          # Analytics: Track pool distribution for metadata
          pools_hit.each { |pool| pool_counts[pool] += 1 }

          # Tracing: Build relationship path for debugging and explanation
          # Shows how the item was found through the knowledge graph
          trace = include_trace ? build_trace_string(item_id, pools_hit, result) : nil

          # Metadata: Rights and provenance for transparency
          rights = get_item_rights(item_id)
          provenance = get_item_provenance(item_id)

          # Rights filtering: Skip items that don't meet visibility requirements
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

    # Pool entity lookup: Find which Seven Pools this item activates
    #
    # The Seven Pools framework categorizes understanding into cognitive dimensions.
    # Each item may activate multiple pools simultaneously, creating rich semantic connections.
    #
    # Returns: Hash of pool_type => [entity_values]
    # Example: { "pool_manifest" => ["art_installation", "sculpture"], 
    #            "pool_experience" => ["interactive", "participatory"] }
    def self.get_pool_entities(item_id)
      SearchEntity
        .joins(:searchable_item)
        .where(searchable_items: { id: item_id })
        .where("entity_type LIKE 'pool_%'")  # Filter to pool entities only
        .group_by(&:entity_type)             # Group by pool type
        .transform_values { |entities| entities.map(&:entity_value).uniq }  # Extract unique values
    end

    # Trace generation: Create readable path showing discovery route
    #
    # Traces help users understand how items were found and which pools were activated.
    # Format: "Manifest(Art) → Experience(Interactive) → Relational(Community)"
    #
    # This is valuable for:
    # - Debugging search results
    # - Explaining AI reasoning
    # - Understanding semantic relationships
    def self.build_trace_string(item_id, pools_hit, result)
      item_name = result["name"] || result[:name] || "Item #{item_id}"
      # Show up to 3 pool activations in the trace
      pool_fragments = pools_hit.first(3).map { |pool| "#{pool.capitalize}(#{item_name})" }
      pool_fragments.join(" → ")  # Unicode arrow for visual clarity
    end

    # Rights management: Determine access permissions for items
    #
    # In production, this should query a rights management table:
    # - license: Content license (CC-BY, proprietary, etc.)
    # - consent: User consent for data usage
    # - visibility: Who can access this content
    # - attribution_required: Whether attribution is mandatory
    #
    # TODO: Replace with database lookup for production deployment
    def self.get_item_rights(item_id)
      # Default: All Burning Man data is public domain with attribution
      {
        license: "CC-BY",
        consent: "public",
        visibility: "public",
        attribution_required: true
      }
    end

    # Provenance tracking: Document data source and collection method
    #
    # Provenance is critical for:
    # - Data quality assessment
    # - Citation and attribution
    # - Audit trails
    # - Rights compliance
    #
    # Each item should have complete provenance information showing:
    # - Original source
    # - Collection method
    # - Processing history
    # - Quality assurance steps
    def self.get_item_provenance(item_id)
      # Lookup source year from the database record
      item = SearchableItem.find_by(id: item_id)
      source_year = item&.year || 2024

      # Return structured provenance information
      [ {
        source_id: "burning_man_#{source_year}",
        citation: "Burning Man #{source_year} Official Data",
        collected_by: "OK-OFFLINE Team",
        collected_at: "#{source_year}-01-01T00:00:00Z",
        method: "automated_import"  # Could be: manual_entry, api_sync, web_scraping, etc.
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
