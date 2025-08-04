module Search
  class EntityExtractionService
    EXTRACTION_MODEL = "gpt-3.5-turbo-0125"
    
    def initialize
      @client = OpenAI::Client.new(
        api_key: ENV['OPENAI_API_KEY']
      )
    end
    
    def extract_entities(text, item_type)
      return [] if text.blank?
      
      system_prompt = build_system_prompt(item_type)
      
      begin
        response = @client.chat.completions.create(
          model: EXTRACTION_MODEL,
          messages: [
            { role: "system", content: system_prompt },
            { role: "user", content: text }
          ],
          response_format: { type: "json_object" },
          temperature: 0.3
        )
        
        result = JSON.parse(response.choices.first.message.content || "{}")
        parse_entities(result)
      rescue => e
        Rails.logger.error("Entity Extraction Error: #{e.message}")
        []
      end
    end
    
    private
    
    def build_system_prompt(item_type)
      base_prompt = <<~PROMPT
        You are an entity extraction system for Burning Man content. 
        Extract relevant entities from the given text and categorize them.
        
        Return a JSON object with the following structure:
        {
          "locations": ["array of location references"],
          "activities": ["array of activities or experiences offered"],
          "themes": ["array of themes or topics"],
          "times": ["array of time references"],
          "people": ["array of notable people mentioned"]
        }
        
        For locations, include:
        - BRC street addresses (e.g., "7:30 & C")
        - Plaza names
        - Deep playa references
        - Camp locations
        
        For activities, include:
        - Workshops, classes, performances
        - Services offered (massage, drinks, etc.)
        - Interactive experiences
        
        For themes, include:
        - Art themes
        - Camp concepts
        - Cultural references
        
        Only include entities with high confidence. Return empty arrays for categories with no entities.
      PROMPT
      
      case item_type
      when 'camp'
        base_prompt + "\nFocus on camp offerings, location, and community themes."
      when 'art'
        base_prompt + "\nFocus on artistic themes, installation concepts, and interactivity."
      when 'event'
        base_prompt + "\nFocus on event activities, timing, and participating entities."
      else
        base_prompt
      end
    end
    
    def parse_entities(result)
      entities = []
      
      # Map extraction results to our entity types
      entity_mappings = {
        'locations' => 'location',
        'activities' => 'activity',
        'themes' => 'theme',
        'times' => 'time',
        'people' => 'person'
      }
      
      entity_mappings.each do |key, entity_type|
        next unless result[key].is_a?(Array)
        
        result[key].each do |value|
          entities << {
            entity_type: entity_type,
            entity_value: value.to_s.strip,
            confidence: 0.9 # High confidence for GPT extractions
          }
        end
      end
      
      entities
    end
  end
end