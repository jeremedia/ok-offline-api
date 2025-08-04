module Research
  class AIAnalysisService
    def initialize
      # Using OpenAI client for AI-powered content analysis
      @client = OpenAI::Client.new(
        api_key: ENV.fetch('OPENAI_API_KEY'),
        log_errors: Rails.env.development?
      )
    end
    
    def analyze_webpage_for_philosophical_content(url, html_content)
      prompt = build_philosophical_analysis_prompt(url, html_content)
      
      response = execute_claude_query(prompt, context: "philosophical_analysis")
      
      begin
        JSON.parse(response)
      rescue JSON::ParserError => e
        Rails.logger.error("Failed to parse Claude response for #{url}: #{e.message}")
        { error: "Failed to parse response", raw_response: response }
      end
    end
    
    def extract_essay_links_from_page(url, html_content)
      prompt = build_link_extraction_prompt(url, html_content)
      
      response = execute_claude_query(prompt, context: "link_extraction")
      
      begin
        result = JSON.parse(response)
        result["links"] || []
      rescue JSON::ParserError => e
        Rails.logger.error("Failed to parse link extraction for #{url}: #{e.message}")
        []
      end
    end
    
    def analyze_content_for_pools(content, content_type)
      prompt = build_pool_analysis_prompt(content, content_type)
      
      response = execute_claude_query(prompt, context: "pool_analysis")
      
      begin
        JSON.parse(response)
      rescue JSON::ParserError => e
        Rails.logger.error("Failed to parse pool analysis: #{e.message}")
        { 
          pool_primary: "idea",
          pool_connections: [],
          themes: [],
          principles: [],
          error: "Failed to parse response"
        }
      end
    end
    
    def extract_structured_content(raw_content, content_type)
      prompt = build_content_extraction_prompt(raw_content, content_type)
      
      response = execute_claude_query(prompt, context: "content_extraction")
      
      begin
        JSON.parse(response)
      rescue JSON::ParserError => e
        Rails.logger.error("Failed to parse content extraction: #{e.message}")
        {
          title: "Unknown",
          content: raw_content&.slice(0, 1000),
          metadata: {},
          error: "Failed to parse response"
        }
      end
    end
    
    private
    
    # Removed SDK check - using OpenAI API directly
    
    def execute_claude_query(prompt, context: nil)
      Rails.logger.info("Executing AI analysis for context: #{context}")
      
      begin
        response = @client.chat(
          parameters: {
            model: "gpt-4.1-nano-2025-04-14",
            messages: [
              { role: "system", content: build_system_prompt(context) },
              { role: "user", content: prompt }
            ],
            response_format: { type: "json_object" },
            temperature: 0.3,
            max_tokens: 2000
          }
        )
        
        response.dig("choices", 0, "message", "content")
        
      rescue => e
        Rails.logger.error("Claude analysis failed: #{e.message}")
        return { error: "Analysis failed", details: e.message }.to_json
      end
    end
    
    def build_system_prompt(context)
      base_prompt = <<~PROMPT
        You are a research assistant specializing in Burning Man philosophical content and culture.
        Your task is to analyze content and extract structured information.
        
        Always respond with valid JSON only. No additional text or explanation.
        Be precise and thorough in your analysis.
      PROMPT
      
      case context
      when "philosophical_analysis"
        base_prompt + <<~CONTEXT
          
          Focus on identifying philosophical essays, foundational texts, and principle-based content.
          Look for content by Larry Harvey, the 10 Principles, theme explanations, and cultural philosophy.
        CONTEXT
      when "link_extraction"
        base_prompt + <<~CONTEXT
          
          Extract links to essays, articles, and philosophical content. 
          Focus on finding actual content links, not navigation or promotional links.
        CONTEXT
      when "pool_analysis"
        base_prompt + <<~CONTEXT
          
          Analyze which of the seven enliteracy pools this content belongs to:
          - Idea Pool: Philosophy, principles, concepts
          - Manifest Pool: Physical implementations
          - Experience Pool: Personal stories, feelings
          - Relational Pool: Connections, networks
          - Evolutionary Pool: Changes over time
          - Practical Pool: How-to knowledge
          - Emanation Pool: Wider impact, influence
        CONTEXT
      when "content_extraction"
        base_prompt + <<~CONTEXT
          
          Extract and structure the content, preserving meaning while organizing it clearly.
          Identify key themes, principles referenced, and cultural significance.
        CONTEXT
      else
        base_prompt
      end
    end
    
    def build_philosophical_analysis_prompt(url, html_content)
      <<~PROMPT
        Analyze this webpage for Burning Man philosophical content.
        
        URL: #{url}
        
        HTML Content:
        #{html_content&.slice(0, 20000)} # Limit content to prevent token overflow
        
        Return a JSON object with this structure:
        {
          "has_philosophical_content": boolean,
          "content_type": "essay|principle|theme|historical|other",
          "title": "string",
          "author": "string or null",
          "estimated_year": number or null,
          "key_themes": ["array", "of", "themes"],
          "principles_referenced": ["array", "of", "principles"],
          "significance": "brief description of importance",
          "extract_worthy": boolean
        }
      PROMPT
    end
    
    def build_link_extraction_prompt(url, html_content)
      <<~PROMPT
        Extract links to philosophical essays, articles, and foundational content from this webpage.
        
        URL: #{url}
        
        HTML Content:
        #{html_content&.slice(0, 15000)}
        
        Return a JSON object with this structure:
        {
          "links": [
            {
              "url": "full URL",
              "title": "link text or title",
              "content_type": "essay|article|principle|theme|historical",
              "priority": "high|medium|low"
            }
          ]
        }
        
        Focus on:
        - Larry Harvey essays and writings
        - Philosophical Center content
        - 10 Principles explanations
        - Theme descriptions and rationales
        - Historical documents and newsletters
        - AfterBurn reports
        
        Ignore navigation, social media, and commercial links.
      PROMPT
    end
    
    def build_pool_analysis_prompt(content, content_type)
      <<~PROMPT
        Analyze this Burning Man content and determine which enliteracy pools it belongs to and connects with.
        
        Content Type: #{content_type}
        
        Content:
        #{content&.slice(0, 10000)}
        
        Return a JSON object with this structure:
        {
          "pool_primary": "idea|manifest|experience|relational|evolutionary|practical|emanation",
          "pool_connections": ["array", "of", "connected", "pools"],
          "themes": ["extracted", "themes"],
          "principles": ["burning", "man", "principles", "referenced"], 
          "entities": {
            "people": ["person names"],
            "locations": ["place names"],
            "concepts": ["key concepts"],
            "years": ["year references"]
          },
          "flows": [
            {
              "from_pool": "pool name",
              "to_pool": "pool name", 
              "connection_type": "manifests_as|creates|influences|etc",
              "description": "how they connect"
            }
          ]
        }
      PROMPT
    end
    
    def build_content_extraction_prompt(raw_content, content_type)
      <<~PROMPT
        Extract and structure this Burning Man content, preserving its meaning and cultural significance.
        
        Content Type: #{content_type}
        
        Raw Content:
        #{raw_content&.slice(0, 15000)}
        
        Return a JSON object with this structure:
        {
          "title": "extracted or generated title",
          "content": "cleaned and structured content",
          "author": "author if identifiable",
          "estimated_year": number or null,
          "content_type": "essay|principle|theme|historical|newsletter|report",
          "metadata": {
            "source": "source identification",
            "principles_embodied": ["array"],
            "themes_explored": ["array"],
            "historical_significance": "description",
            "target_audience": "who this is for",
            "key_concepts": ["important concepts"]
          },
          "searchable_text": "optimized text for search and embeddings"
        }
      PROMPT
    end
  end
end