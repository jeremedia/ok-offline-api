# frozen_string_literal: true

module Mcp
  class SetPersonaTool
    VALID_STYLE_MODES = %w[off light medium strong].freeze
    VALID_STYLE_SCOPES = %w[narration_only examples_only full_answer].freeze
    VALID_RIGHTS_LEVELS = %w[public internal any].freeze
    
    def self.call(persona:, style_mode: 'light', style_scope: 'full_answer', era: nil, require_rights: 'public', max_quote_pct: 0.1)
      # Validate inputs
      return validation_error("Invalid style_mode") unless VALID_STYLE_MODES.include?(style_mode)
      return validation_error("Invalid style_scope") unless VALID_STYLE_SCOPES.include?(style_scope)
      return validation_error("Invalid require_rights") unless VALID_RIGHTS_LEVELS.include?(require_rights)
      return validation_error("max_quote_pct out of range") unless (0.0..0.2).cover?(max_quote_pct)
      
      # Check if persona style is enabled
      unless Rails.application.config.x.persona_style&.enabled
        return feature_disabled_error
      end
      
      # Return off response if style_mode is 'off'
      return off_response if style_mode == 'off'
      
      # Generate cache key
      cache_key = build_cache_key(persona, era, require_rights)
      
      # Try cache first
      cached_result = Rails.cache.read(cache_key)
      if cached_result
        Rails.logger.info "SetPersonaTool: Cache hit for #{persona}"
        return cached_result.merge(meta: { cache: "hit", built_by_job: false })
      end
      
      Rails.logger.info "SetPersonaTool: Cache miss for #{persona}, attempting fast path build"
      
      # Cache miss - try fast synchronous build with timeout
      fast_result = attempt_fast_build(persona, era, require_rights)
      
      if fast_result[:ok]
        Rails.logger.info "SetPersonaTool: Fast build succeeded for #{persona}"
        return fast_result.merge(meta: fast_result[:meta].merge(cache: "miss"))
      end
      
      # Fast build failed or timed out - enqueue job and return minimal capsule
      Rails.logger.info "SetPersonaTool: Fast build failed, enqueuing job for #{persona}"
      enqueue_build_job(persona, era, require_rights)
      
      minimal_capsule_response(persona, fast_result[:error])
      
    rescue => e
      Rails.logger.error "SetPersonaTool error: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      
      {
        ok: false,
        error: "Persona setup failed: #{e.message}",
        persona_id: nil,
        persona_label: nil
      }
    end
    
    private
    
    def self.validation_error(message)
      {
        ok: false,
        error: message,
        error_code: "invalid_params",
        persona_id: nil,
        persona_label: nil
      }
    end
    
    def self.feature_disabled_error
      {
        ok: false,
        error: "Persona style feature is not enabled",
        error_code: "feature_disabled",
        persona_id: nil,
        persona_label: nil
      }
    end
    
    def self.off_response
      {
        ok: true,
        persona_id: nil,
        persona_label: "Style mode disabled",
        style_capsule: nil,
        style_confidence: 0.0,
        rights_summary: { quotable: false, attribution_required: false },
        sources: [],
        meta: { cache: "n/a", built_by_job: false, style_mode: "off" }
      }
    end
    
    def self.build_cache_key(persona, era, require_rights)
      graph_version = "2025.07"  # Should come from config
      lexicon_version = "2025.07"  # Should come from config
      
      # Normalize persona to ID format if needed
      persona_id = persona.include?(':') ? persona : "person:#{persona.downcase.gsub(/\s+/, '_')}"
      
      "style_capsule:#{persona_id}:#{era || 'any'}:#{require_rights}:#{graph_version}:#{lexicon_version}"
    end
    
    def self.attempt_fast_build(persona, era, require_rights)
      # Try to build capsule synchronously with a timeout
      timeout_seconds = 10  # Fast path should be very quick
      
      begin
        Timeout::timeout(timeout_seconds) do
          result = Persona::StyleCapsuleBuilder.call(
            persona_id: persona.include?(':') ? persona : "person:#{persona.downcase.gsub(/\s+/, '_')}",
            era: era,
            require_rights: require_rights
          )
          
          # Mark as fast path build
          if result[:ok]
            result[:meta] = result[:meta].merge(built_by_job: false, fast_path: true)
          end
          
          result
        end
      rescue Timeout::Error
        Rails.logger.info "SetPersonaTool: Fast build timed out for #{persona}"
        { ok: false, error: "Build timed out" }
      rescue => e
        Rails.logger.error "SetPersonaTool: Fast build failed for #{persona}: #{e.message}"
        { ok: false, error: e.message }
      end
    end
    
    def self.enqueue_build_job(persona, era, require_rights)
      persona_id = persona.include?(':') ? persona : "person:#{persona.downcase.gsub(/\s+/, '_')}"
      
      BuildStyleCapsuleJob.perform_later(
        persona_id: persona_id,
        era: era,
        require_rights: require_rights
      )
      
      Rails.logger.info "SetPersonaTool: Enqueued BuildStyleCapsuleJob for #{persona_id}"
    end
    
    def self.minimal_capsule_response(persona, error_message)
      # Return a minimal response when full build is not immediately available
      persona_id = persona.include?(':') ? persona : "person:#{persona.downcase.gsub(/\s+/, '_')}"
      persona_label = persona.include?(':') ? persona.split(':', 2).last.humanize.titleize : persona.titleize
      
      {
        ok: true,
        persona_id: persona_id,
        persona_label: persona_label,
        style_capsule: {
          tone: ["building"],
          cadence: "pending analysis",
          devices: [],
          vocabulary: [],
          metaphors: [],
          dos: ["wait for full analysis"],
          donts: ["use incomplete data"],
          era: "unknown"
        },
        style_confidence: 0.1,  # Very low confidence for minimal capsule
        rights_summary: {
          quotable: false,  # Conservative default
          attribution_required: true,
          attribution_text: "Style analysis in progress",
          visibility: "restricted"
        },
        sources: [],
        meta: {
          cache: "miss", 
          built_by_job: true,
          minimal_capsule: true,
          build_status: "enqueued",
          error: error_message
        }
      }
    end
    
    # Check if capsule already exists in database
    def self.find_existing_capsule(persona_id, era, require_rights)
      graph_version = "2025.07"
      lexicon_version = "2025.07"
      
      StyleCapsule.valid_for(
        persona_id: persona_id,
        era: era,
        rights_scope: require_rights,
        graph_version: graph_version,
        lexicon_version: lexicon_version
      ).first
    end
    
    # Handle specific error codes
    def self.handle_build_error(error_message, persona)
      case error_message
      when /persona not found/i
        {
          ok: false,
          error: "Persona not found in dataset",
          error_code: "persona_not_found",
          persona_id: persona,
          persona_label: nil
        }
      when /rights restricted/i
        {
          ok: false,
          error: "Insufficient rights for requested access level",
          error_code: "rights_restricted", 
          persona_id: persona,
          persona_label: nil
        }
      when /low corpus/i
        {
          ok: false,
          error: "Insufficient content available for style analysis",
          error_code: "low_corpus",
          persona_id: persona,
          persona_label: nil
        }
      else
        {
          ok: false,
          error: "Build failed: #{error_message}",
          error_code: "build_failed",
          persona_id: persona,
          persona_label: nil
        }
      end
    end
  end
end