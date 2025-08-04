module Search
  class PoolEntityExtractionService
    EXTRACTION_MODEL = "gpt-4.1-nano-2025-04-14"
    
    # Seven Pools of Enliteracy
    POOLS = {
      idea: "Abstract concepts, principles, philosophies, and theoretical frameworks",
      manifest: "Physical structures, camps, art installations, and tangible creations",
      experience: "Personal stories, emotions, transformative moments, and sensory memories",
      relational: "Connections between people, community dynamics, and social interactions",
      evolutionary: "Changes over time, historical progressions, and cultural evolution",
      practical: "How-to knowledge, survival tips, operational wisdom, and techniques",
      emanation: "Spiritual insights, collective consciousness, and emergent wisdom"
    }
    
    def initialize
      @client = OpenAI::Client.new(
        api_key: ENV.fetch('OPENAI_API_KEY')
      )
    end
    
    def extract_pool_entities(text, item_type)
      return [] if text.blank?
      
      system_prompt = build_pool_extraction_prompt(item_type)
      
      begin
        puts "DEBUG: Starting pool entity extraction with model: #{EXTRACTION_MODEL}"
        puts "DEBUG: Text: #{text[0..100]}"
        
        response = @client.chat(
          model: EXTRACTION_MODEL,
          messages: [
            { role: "system", content: system_prompt },
            { role: "user", content: text }
          ],
          response_format: { type: "json_object" },
          temperature: 0.3
        )
        
        puts "DEBUG: Response class: #{response.class}"
        puts "DEBUG: Response keys: #{response.respond_to?(:keys) ? response.keys : 'No keys method'}"
        
        # Handle both old and new SDK response formats
        content = if response.respond_to?(:dig)
          response.dig("choices", 0, "message", "content")
        else
          response.choices&.first&.message&.content
        end
        
        puts "DEBUG: Extracted content: #{content}"
        
        result = JSON.parse(content || "{}")
        puts "DEBUG: Parsed result: #{result.inspect}"
        
        entities = parse_pool_entities(result)
        puts "DEBUG: Final entities: #{entities.inspect}"
        
        entities
      rescue => e
        Rails.logger.error("Pool Entity Extraction Error: #{e.message}")
        puts "DEBUG: Error occurred: #{e.message}"
        puts "DEBUG: Error backtrace: #{e.backtrace.first(3)}"
        []
      end
    end
    
    private
    
    def build_pool_extraction_prompt(item_type)
      <<~PROMPT
        You are an entity extraction system for the Seven Pools of Enliteracy framework.
        Extract entities that represent concepts within each pool from the given text.
        
        The Seven Pools are:
        #{POOLS.map { |pool, desc| "- #{pool}: #{desc}" }.join("\n")}
        
        Return a JSON object with pool entities:
        {
          "pool_idea": ["philosophical concepts, principles, theories"],
          "pool_manifest": ["physical objects, structures, installations"],
          "pool_experience": ["emotions, sensory details, transformative moments"],
          "pool_relational": ["relationships, connections, community aspects"],
          "pool_evolutionary": ["historical references, changes, progressions"],
          "pool_practical": ["skills, techniques, how-to knowledge"],
          "pool_emanation": ["spiritual insights, collective wisdom, emergence"]
        }
        
        For #{item_type} content, focus on:
        #{pool_focus_for_item_type(item_type)}
        
        Extract 3-7 entities per relevant pool. Include only high-confidence entities.
        Keep entity values concise (2-5 words).
      PROMPT
    end
    
    def pool_focus_for_item_type(item_type)
      case item_type
      when 'philosophical_text'
        "Idea pool (principles, concepts), Emanation pool (spiritual insights)"
      when 'experience_story'
        "Experience pool (emotions, sensations), Relational pool (connections)"
      when 'practical_guide'
        "Practical pool (skills, techniques), Manifest pool (tools, materials)"
      when 'camp'
        "Manifest pool (structures), Relational pool (community), Practical pool (offerings)"
      when 'art'
        "Manifest pool (physical form), Experience pool (interaction), Idea pool (concepts)"
      when 'event'
        "Experience pool (activities), Relational pool (gatherings), Practical pool (skills)"
      else
        "All relevant pools based on content"
      end
    end
    
    def parse_pool_entities(result)
      entities = []
      
      POOLS.keys.each do |pool|
        pool_key = "pool_#{pool}"
        next unless result[pool_key].is_a?(Array)
        
        result[pool_key].each do |value|
          next if value.to_s.strip.empty?
          
          entities << {
            type: pool_key,
            value: value.to_s.strip.downcase,
            confidence: 0.9
          }
        end
      end
      
      entities.uniq { |e| [e[:type], e[:value]] }
    end
  end
end