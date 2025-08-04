# frozen_string_literal: true

module Persona
  class StyleFeatureExtractor
    # Extract writing style features from corpus using deterministic heuristics
    # Returns tone, cadence, devices, vocabulary, metaphors, dos/donts
    
    def self.call(corpus_items)
      new(corpus_items).extract
    end
    
    def initialize(corpus_items)
      @corpus_items = corpus_items
      @all_text = extract_all_text
      @sentences = extract_sentences
      @words = extract_words
    end
    
    def extract
      return error("Empty corpus") if @all_text.blank?
      
      {
        tone: extract_tone,
        cadence: extract_cadence,
        devices: extract_rhetorical_devices,
        vocabulary: extract_key_vocabulary,
        metaphors: extract_metaphors,
        dos: extract_dos,
        donts: extract_donts,
        era: extract_era_indicators,
        confidence_factors: calculate_confidence_factors
      }
    rescue => e
      Rails.logger.error "StyleFeatureExtractor error: #{e.message}"
      error("Feature extraction failed: #{e.message}")
    end
    
    private
    
    def extract_all_text
      @corpus_items.map { |item| "#{item[:title]} #{item[:content]}" }.join(' ')
                  .gsub(/[^\w\s.!?;:,'-]/, ' ')
                  .squeeze(' ')
    end
    
    def extract_sentences
      @all_text.split(/[.!?]+/).map(&:strip).reject(&:blank?)
    end
    
    def extract_words
      @all_text.downcase.scan(/\b[a-z]{2,}\b/)
    end
    
    def extract_tone
      tone_indicators = {
        'reflective' => %w[reflect consider ponder think wonder contemplate],
        'inspirational' => %w[inspire create build dream achieve transform],
        'practical' => %w[do make work build implement organize plan],
        'philosophical' => %w[principle truth meaning essence nature being],
        'communal' => %w[community together share gift participate belong],
        'visionary' => %w[vision future possibility imagine potential become],
        'direct' => %w[must should will need important essential clear],
        'playful' => %w[play fun joy celebrate dance laugh creative]
      }
      
      detected_tones = []
      text_lower = @all_text.downcase
      
      tone_indicators.each do |tone, keywords|
        matches = keywords.count { |word| text_lower.include?(word) }
        if matches >= 2  # Need at least 2 keyword matches
          detected_tones << tone
        end
      end
      
      detected_tones.empty? ? ['neutral'] : detected_tones.first(3)
    end
    
    def extract_cadence
      return "unknown" if @sentences.empty?
      
      sentence_lengths = @sentences.map { |s| s.split.length }
      avg_length = sentence_lengths.sum.to_f / sentence_lengths.length
      
      case avg_length
      when 0..8
        "short and punchy"
      when 9..15
        "medium rhythmic"
      when 16..25
        "flowing extended"
      else
        "long contemplative"
      end
    end
    
    def extract_rhetorical_devices
      devices = []
      text_lower = @all_text.downcase
      
      # Detect triads (groups of three)
      if text_lower.match?(/\w+,\s*\w+,\s*(and\s+)?\w+/) || text_lower.include?('three')
        devices << 'triads'
      end
      
      # Detect repetition patterns
      words = @words
      repeated_words = words.group_by(&:itself).select { |word, occurrences| 
        occurrences.length > 3 && word.length > 4 
      }
      devices << 'repetition' if repeated_words.any?
      
      # Detect questions
      question_count = @all_text.count('?')
      devices << 'rhetorical_questions' if question_count > 2
      
      # Detect imperatives (commands)
      imperative_starters = %w[do make create build give share participate]
      imperative_count = @sentences.count do |sentence|
        first_word = sentence.split.first&.downcase
        imperative_starters.include?(first_word)
      end
      devices << 'imperatives' if imperative_count > 1
      
      # Detect parallel structure
      devices << 'parallel_structure' if detect_parallel_structure
      
      devices
    end
    
    def extract_key_vocabulary
      # Use TF-IDF-like approach to find distinctive words
      common_words = %w[the and or but for with from that this these those what where when how why]
      
      word_freq = @words.reject { |w| common_words.include?(w) || w.length < 4 }
                        .group_by(&:itself)
                        .transform_values(&:length)
                        .select { |word, count| count >= 2 }
      
      # Score words by frequency and length
      scored_words = word_freq.map do |word, freq|
        score = freq * Math.log(word.length)
        [word, score]
      end
      
      scored_words.sort_by { |word, score| -score }
                  .first(15)
                  .map(&:first)
    end
    
    def extract_metaphors
      metaphor_patterns = [
        /\b\w+\s+is\s+a\s+\w+/,
        /\b\w+\s+as\s+\w+/,
        /like\s+\w+/,
        /vessel|journey|path|fire|light|circle|gift/
      ]
      
      detected_metaphors = []
      
      metaphor_patterns.each do |pattern|
        matches = @all_text.scan(pattern)
        detected_metaphors.concat(matches.flatten.uniq)
      end
      
      # Look for specific Burning Man metaphors
      burning_man_metaphors = %w[playa temple effigy gift economy radical self-reliance]
      burning_man_metaphors.each do |metaphor|
        if @all_text.downcase.include?(metaphor)
          detected_metaphors << metaphor
        end
      end
      
      detected_metaphors.uniq.first(8)
    end
    
    def extract_dos
      dos_patterns = [
        /should\s+([^.!?]+)/,
        /must\s+([^.!?]+)/,
        /always\s+([^.!?]+)/,
        /important\s+to\s+([^.!?]+)/
      ]
      
      dos = []
      
      dos_patterns.each do |pattern|
        @sentences.each do |sentence|
          matches = sentence.scan(pattern)
          matches.each do |match|
            cleaned = match.first&.strip&.downcase
            dos << cleaned if cleaned && cleaned.length > 5
          end
        end
      end
      
      dos.uniq.first(5)
    end
    
    def extract_donts
      donts_patterns = [
        /should\s+not\s+([^.!?]+)/,
        /never\s+([^.!?]+)/,
        /avoid\s+([^.!?]+)/,
        /don't\s+([^.!?]+)/
      ]
      
      donts = []
      
      donts_patterns.each do |pattern|
        @sentences.each do |sentence|
          matches = sentence.scan(pattern)
          matches.each do |match|
            cleaned = match.first&.strip&.downcase
            donts << cleaned if cleaned && cleaned.length > 5
          end
        end
      end
      
      donts.uniq.first(5)
    end
    
    def extract_era_indicators
      years = @corpus_items.map { |item| item[:year] }.compact.sort
      return "unknown" if years.empty?
      
      earliest = years.min
      latest = years.max
      
      if earliest == latest
        earliest.to_s
      else
        "#{earliest}–#{latest}"
      end
    end
    
    def detect_parallel_structure
      # Look for sentences with similar structure
      sentence_patterns = @sentences.map do |sentence|
        words = sentence.split
        next nil if words.length < 3
        
        # Create a pattern based on first few words
        words.first(3).map do |word|
          case word.downcase
          when /^(we|i|you|they)$/ then 'PRONOUN'
          when /^(will|should|must|can)$/ then 'MODAL'
          when /^(and|but|or)$/ then 'CONJUNCTION'
          when /ing$/ then 'GERUND'
          else 'WORD'
          end
        end.join('_')
      end.compact
      
      # Count pattern frequencies
      pattern_counts = sentence_patterns.group_by(&:itself)
                                       .select { |pattern, occurrences| occurrences.length >= 2 }
      
      pattern_counts.any?
    end
    
    def calculate_confidence_factors
      factors = {}
      
      # Text volume factor
      factors[:text_volume] = case @all_text.length
                             when 0..500 then 0.3
                             when 501..2000 then 0.6
                             when 2001..5000 then 0.8
                             else 1.0
                             end
      
      # Corpus diversity factor
      strategies = @corpus_items.map { |item| item[:strategy] }.uniq
      factors[:strategy_diversity] = [strategies.length / 5.0, 1.0].min
      
      # Pool coverage factor
      all_pools = @corpus_items.flat_map { |item| item[:pools_hit] }.uniq
      factors[:pool_coverage] = [all_pools.length / 7.0, 1.0].min
      
      # Era consistency factor
      years = @corpus_items.map { |item| item[:year] }.compact
      if years.any?
        year_span = years.max - years.min
        factors[:era_consistency] = case year_span
                                   when 0..2 then 1.0
                                   when 3..5 then 0.8
                                   when 6..10 then 0.6
                                   else 0.4
                                   end
      else
        factors[:era_consistency] = 0.5
      end
      
      factors
    end
    
    def error(message)
      {
        error: message,
        tone: [],
        cadence: "unknown",
        devices: [],
        vocabulary: [],
        metaphors: [],
        dos: [],
        donts: [],
        era: "unknown",
        confidence_factors: {}
      }
    end
  end
end