# frozen_string_literal: true

module Persona
  class RightsSummarizer
    # Analyze rights across corpus items and determine quotability/attribution
    
    def self.call(corpus_items, require_rights: 'public')
      new(corpus_items, require_rights).summarize
    end
    
    def initialize(corpus_items, require_rights)
      @corpus_items = corpus_items
      @require_rights = require_rights
    end
    
    def summarize
      return error("Empty corpus") if @corpus_items.empty?
      
      rights_analysis = analyze_rights_distribution
      
      {
        ok: true,
        quotable: determine_quotability(rights_analysis),
        attribution_required: determine_attribution_requirement(rights_analysis),
        attribution_text: generate_attribution_text(rights_analysis),
        visibility: determine_visibility_level(rights_analysis),
        rights_breakdown: rights_analysis,
        restrictions: identify_restrictions(rights_analysis),
        public_percentage: calculate_public_percentage(rights_analysis)
      }
    rescue => e
      Rails.logger.error "RightsSummarizer error: #{e.message}"
      error("Rights analysis failed: #{e.message}")
    end
    
    private
    
    def analyze_rights_distribution
      rights_counts = {
        visibility: Hash.new(0),
        license: Hash.new(0),
        consent: Hash.new(0),
        attribution_required: Hash.new(0)
      }
      
      @corpus_items.each do |item|
        rights = item[:rights] || default_rights
        
        rights_counts[:visibility][rights[:visibility]] += 1
        rights_counts[:license][rights[:license]] += 1
        rights_counts[:consent][rights[:consent]] += 1
        rights_counts[:attribution_required][rights[:attribution_required]] += 1
      end
      
      rights_counts
    end
    
    def determine_quotability(rights_analysis)
      # Can we quote from this corpus?
      
      # Check visibility requirements
      case @require_rights
      when 'public'
        # Must be public to quote publicly
        public_count = rights_analysis[:visibility]['public'] || 0
        total_count = @corpus_items.length
        
        # Need at least 60% public content to be quotable
        (public_count.to_f / total_count) >= 0.6
        
      when 'internal'
        # Internal visibility is okay for internal use
        public_count = rights_analysis[:visibility]['public'] || 0
        internal_count = rights_analysis[:visibility]['internal'] || 0
        total_count = @corpus_items.length
        
        ((public_count + internal_count).to_f / total_count) >= 0.6
        
      when 'any'
        # Any visibility level is fine
        true
      else
        false
      end
    end
    
    def determine_attribution_requirement(rights_analysis)
      # Do we need attribution?
      
      attribution_required_count = rights_analysis[:attribution_required][true] || 0
      total_count = @corpus_items.length
      
      # If more than 25% require attribution, then attribution is required
      (attribution_required_count.to_f / total_count) > 0.25
    end
    
    def generate_attribution_text(rights_analysis)
      # Generate appropriate attribution text
      
      if determine_attribution_requirement(rights_analysis)
        # Look at corpus to determine appropriate attribution
        sources = @corpus_items.flat_map { |item| item[:provenance] || [] }
                               .map { |prov| prov[:citation] }
                               .compact
                               .uniq
        
        if sources.any?
          primary_source = sources.first
          if sources.length == 1
            "Based on: #{primary_source}"
          else
            "Based on: #{primary_source} and #{sources.length - 1} other sources"
          end
        else
          "Attribution required - see source documentation"
        end
      else
        nil
      end
    end
    
    def determine_visibility_level(rights_analysis)
      # What's the most restrictive visibility level we can support?
      
      case @require_rights
      when 'public'
        'public'
      when 'internal'
        # Return the most permissive level available
        if rights_analysis[:visibility]['public'] && rights_analysis[:visibility]['public'] > 0
          'public'
        elsif rights_analysis[:visibility]['internal'] && rights_analysis[:visibility]['internal'] > 0
          'internal'
        else
          'restricted'
        end
      when 'any'
        # Return the most common visibility level
        rights_analysis[:visibility].max_by { |level, count| count }&.first || 'unknown'
      else
        'restricted'
      end
    end
    
    def identify_restrictions(rights_analysis)
      restrictions = []
      
      # Check for private content
      private_count = rights_analysis[:visibility]['private'] || 0
      if private_count > 0
        restrictions << {
          type: 'private_content',
          count: private_count,
          description: "#{private_count} items have private visibility"
        }
      end
      
      # Check for restrictive licenses
      restrictive_licenses = (rights_analysis[:license].keys - ['CC-BY', 'CC-BY-SA', 'Public Domain'])
      if restrictive_licenses.any?
        restrictive_count = restrictive_licenses.sum { |license| rights_analysis[:license][license] }
        restrictions << {
          type: 'restrictive_licenses',
          count: restrictive_count,
          description: "#{restrictive_count} items have restrictive licenses"
        }
      end
      
      # Check for consent requirements
      no_consent_count = rights_analysis[:consent]['withdrawn'] || 0
      if no_consent_count > 0
        restrictions << {
          type: 'consent_withdrawn',
          count: no_consent_count,
          description: "#{no_consent_count} items have withdrawn consent"
        }
      end
      
      restrictions
    end
    
    def calculate_public_percentage(rights_analysis)
      public_count = rights_analysis[:visibility]['public'] || 0
      total_count = @corpus_items.length
      
      return 0.0 if total_count == 0
      
      (public_count.to_f / total_count * 100).round(1)
    end
    
    # Experience pool content handling
    def experience_content_quotable?(item)
      # Experience content (personal stories, quotes) needs explicit consent
      pools_hit = item[:pools_hit] || []
      
      if pools_hit.include?('experience')
        rights = item[:rights] || default_rights
        
        # Experience content needs explicit public consent to be quotable
        rights[:consent] == 'public' && rights[:visibility] == 'public'
      else
        # Non-experience content follows normal rules
        true
      end
    end
    
    def filter_quotable_items
      # Return only items that can be quoted given current requirements
      @corpus_items.select do |item|
        rights = item[:rights] || default_rights
        
        # Check visibility requirement
        visibility_ok = case @require_rights
                       when 'public'
                         rights[:visibility] == 'public'
                       when 'internal'
                         ['public', 'internal'].include?(rights[:visibility])
                       when 'any'
                         true
                       else
                         false
                       end
        
        # Check experience content consent
        experience_ok = experience_content_quotable?(item)
        
        visibility_ok && experience_ok
      end
    end
    
    def default_rights
      {
        license: "CC-BY",
        consent: "public",
        visibility: "public",
        attribution_required: true
      }
    end
    
    def error(message)
      {
        ok: false,
        error: message,
        quotable: false,
        attribution_required: true,
        attribution_text: nil,
        visibility: 'restricted',
        rights_breakdown: {},
        restrictions: [],
        public_percentage: 0.0
      }
    end
  end
end