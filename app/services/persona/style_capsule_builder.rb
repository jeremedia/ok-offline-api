# frozen_string_literal: true

module Persona
  class StyleCapsuleBuilder
    # Orchestrates the complete style capsule building pipeline
    # resolver → collector → extractor → rights → persist → cache
    
    def self.call(persona_id:, persona_label: nil, era: nil, require_rights: 'public', graph_version: nil, lexicon_version: nil)
      new(
        persona_id: persona_id,
        persona_label: persona_label,
        era: era,
        require_rights: require_rights,
        graph_version: graph_version,
        lexicon_version: lexicon_version
      ).build
    end
    
    def initialize(persona_id:, persona_label: nil, era: nil, require_rights: 'public', graph_version: nil, lexicon_version: nil)
      @persona_id = persona_id
      @persona_label = persona_label
      @era = era
      @require_rights = require_rights
      @graph_version = graph_version || current_graph_version
      @lexicon_version = lexicon_version || current_lexicon_version
      @start_time = Time.current
    end
    
    def build
      Rails.logger.info "Building style capsule for #{@persona_id}"
      
      # Step 1: Resolve persona if needed
      persona_resolution = resolve_persona_if_needed
      return persona_resolution unless persona_resolution[:ok]
      
      # Step 2: Collect corpus
      ActiveSupport::Notifications.instrument('persona.collect_corpus', persona_id: @persona_id) do
        corpus_result = collect_corpus
        return corpus_result unless corpus_result[:ok]
        @corpus_items = corpus_result[:corpus_items]
      end
      
      # Step 3: Extract style features
      style_features = nil
      ActiveSupport::Notifications.instrument('persona.extract_features', persona_id: @persona_id) do
        style_features = extract_style_features
        return style_features if style_features[:error]
      end
      
      # Step 4: Analyze rights
      rights_summary = nil
      ActiveSupport::Notifications.instrument('persona.analyze_rights', persona_id: @persona_id) do
        rights_result = analyze_rights
        return rights_result unless rights_result[:ok]
        rights_summary = rights_result
      end
      
      # Step 5: Calculate confidence
      style_confidence = calculate_style_confidence(style_features, rights_summary)
      
      # Step 6: Build final capsule
      capsule_data = build_capsule_data(style_features, rights_summary, style_confidence)
      
      # Step 7: Persist to database
      style_capsule = persist_capsule(capsule_data, style_confidence)
      return error("Failed to persist capsule") unless style_capsule
      
      # Step 8: Write to cache
      cache_result = write_to_cache(style_capsule, capsule_data)
      
      # Step 9: Build final response
      build_response(style_capsule, capsule_data, cache_result)
      
    rescue => e
      Rails.logger.error "StyleCapsuleBuilder error: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      error("Capsule build failed: #{e.message}")
    end
    
    private
    
    def resolve_persona_if_needed
      if @persona_label.present?
        # Already have label, just validate persona_id format
        { ok: true, persona_id: @persona_id, persona_label: @persona_label }
      else
        # Need to resolve persona_id to get label
        PersonaResolver.call(@persona_id)
      end
    end
    
    def collect_corpus
      StyleCorpusCollector.call(
        persona_id: @persona_id,
        era: @era,
        require_rights: @require_rights
      )
    end
    
    def extract_style_features
      StyleFeatureExtractor.call(@corpus_items)
    end
    
    def analyze_rights
      RightsSummarizer.call(@corpus_items, require_rights: @require_rights)
    end
    
    def calculate_style_confidence(style_features, rights_summary)
      # Combine multiple confidence factors
      confidence_factors = style_features[:confidence_factors] || {}
      
      base_confidence = [
        confidence_factors[:text_volume] || 0.5,
        confidence_factors[:strategy_diversity] || 0.5,
        confidence_factors[:pool_coverage] || 0.5,
        confidence_factors[:era_consistency] || 0.5
      ].sum / 4.0
      
      # Apply rights penalty
      rights_penalty = calculate_rights_penalty(rights_summary)
      
      # Apply corpus size bonus/penalty
      corpus_size_factor = calculate_corpus_size_factor
      
      # Apply era specificity bonus
      era_bonus = @era.present? ? 0.1 : 0.0
      
      # Final confidence calculation
      final_confidence = [
        base_confidence - rights_penalty + corpus_size_factor + era_bonus,
        1.0
      ].min
      
      [final_confidence, 0.0].max.round(2)
    end
    
    def calculate_rights_penalty(rights_summary)
      return 0.0 unless rights_summary[:ok]
      
      # Penalty for low public percentage
      public_pct = rights_summary[:public_percentage] || 0.0
      public_penalty = public_pct < 60.0 ? 0.2 : 0.0
      
      # Penalty for restrictions
      restrictions_count = rights_summary[:restrictions]&.length || 0
      restrictions_penalty = restrictions_count * 0.1
      
      # Penalty if not quotable
      quotable_penalty = rights_summary[:quotable] ? 0.0 : 0.3
      
      public_penalty + restrictions_penalty + quotable_penalty
    end
    
    def calculate_corpus_size_factor
      corpus_size = @corpus_items.length
      
      case corpus_size
      when 0..2
        -0.3  # Too small
      when 3..5
        -0.1  # Small
      when 6..15
        0.0   # Good
      when 16..25
        0.1   # Large
      else
        0.2   # Very large
      end
    end
    
    def build_capsule_data(style_features, rights_summary, style_confidence)
      {
        persona_id: @persona_id,
        persona_label: @persona_label,
        style_capsule: {
          tone: style_features[:tone],
          cadence: style_features[:cadence],
          devices: style_features[:devices],
          vocabulary: style_features[:vocabulary],
          metaphors: style_features[:metaphors],
          dos: style_features[:dos],
          donts: style_features[:donts],
          era: style_features[:era]
        },
        style_confidence: style_confidence,
        rights_summary: {
          quotable: rights_summary[:quotable],
          attribution_required: rights_summary[:attribution_required],
          attribution_text: rights_summary[:attribution_text],
          visibility: rights_summary[:visibility]
        },
        sources: build_source_summary,
        meta: {
          cache: "miss",
          built_by_job: false,
          execution_time: (Time.current - @start_time).round(3),
          corpus_size: @corpus_items.length,
          graph_version: @graph_version,
          lexicon_version: @lexicon_version
        }
      }
    end
    
    def build_source_summary
      # Create a summary of top sources used
      source_counts = {}
      
      @corpus_items.each do |item|
        provenance = item[:provenance] || []
        provenance.each do |prov|
          key = prov[:source_id] || "unknown"
          source_counts[key] = (source_counts[key] || 0) + 1
        end
      end
      
      # Build source objects for top sources
      top_sources = source_counts.sort_by { |source, count| -count }.first(5)
      
      top_sources.map do |source_id, count|
        # Find a representative item for this source
        representative = @corpus_items.find do |item|
          item[:provenance]&.any? { |prov| prov[:source_id] == source_id }
        end
        
        if representative
          {
            id: source_id,
            title: representative[:title],
            year: representative[:year],
            count: count
          }
        else
          {
            id: source_id,
            title: source_id.humanize,
            year: 2024,
            count: count
          }
        end
      end
    end
    
    def persist_capsule(capsule_data, style_confidence)
      ttl_days = Rails.application.config.x.persona_style&.ttl_days || 7
      expires_at = Time.current + ttl_days.days
      
      StyleCapsule.create!(
        persona_id: @persona_id,
        persona_label: @persona_label,
        era: @era,
        rights_scope: @require_rights,
        capsule_json: capsule_data[:style_capsule],
        confidence: style_confidence,
        sources_json: capsule_data[:sources],
        graph_version: @graph_version,
        lexicon_version: @lexicon_version,
        expires_at: expires_at
      )
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to persist StyleCapsule: #{e.message}"
      nil
    end
    
    def write_to_cache(style_capsule, capsule_data)
      cache_key = style_capsule.cache_key_for_lookup
      ttl = style_capsule.ttl_seconds
      
      cache_payload = {
        ok: true,
        persona_id: capsule_data[:persona_id],
        persona_label: capsule_data[:persona_label],
        style_capsule: capsule_data[:style_capsule],
        style_confidence: capsule_data[:style_confidence],
        rights_summary: capsule_data[:rights_summary],
        sources: capsule_data[:sources]
      }
      
      Rails.cache.write(cache_key, cache_payload, expires_in: ttl)
      
      { cache_key: cache_key, ttl: ttl, success: true }
    rescue => e
      Rails.logger.error "Failed to write to cache: #{e.message}"
      { success: false, error: e.message }
    end
    
    def build_response(style_capsule, capsule_data, cache_result)
      capsule_data.merge(
        ok: true,
        meta: capsule_data[:meta].merge(
          cached: cache_result[:success],
          cache_key: cache_result[:cache_key],
          ttl_seconds: style_capsule.ttl_seconds
        )
      )
    end
    
    def current_graph_version
      "2025.07"  # Should come from configuration
    end
    
    def current_lexicon_version
      "2025.07"  # Should come from configuration
    end
    
    def error(message)
      {
        ok: false,
        error: message,
        persona_id: @persona_id,
        persona_label: @persona_label,
        execution_time: (Time.current - @start_time).round(3)
      }
    end
  end
end