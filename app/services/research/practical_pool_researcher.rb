require 'nokogiri'
require_relative 'ai_analysis_service'

module Research
  class PracticalPoolResearcher
    include HTTParty
    
    def initialize
      @base_urls = {
        survival: "https://survival.burningman.org/",
        building: "https://burningman.org/event/preparation/",
        playa_tech: "https://burningman.org/event/preparation/playa-living/",
        first_timer: "https://burningman.org/event/preparation/first-timers-guide/",
        leaving_no_trace: "https://burningman.org/event/preparation/leaving-no-trace/"
      }
      @headers = {
        'User-Agent' => 'OK-OFFLINE Research Bot 1.0 (Educational/Non-commercial)',
        'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
      }
      @rate_limit = 2.seconds
      @ai_service = ::Research::AIAnalysisService.new
    end
    
    def research_practical_pool
      puts "🔧 Starting Practical Pool Research"
      puts "=" * 60
      puts "Collecting how-to guides, survival tips, and operational wisdom..."
      
      existing_urls = get_existing_urls
      puts "   Already have #{existing_urls.size} practical guides"
      
      results = {
        survival_guides: research_survival_guides(existing_urls),
        building_guides: research_building_techniques(existing_urls),
        moop_guides: research_moop_prevention(existing_urls),
        weather_prep: research_weather_preparation(existing_urls),
        health_safety: research_health_safety_guides(existing_urls),
        camp_setup: research_camp_setup_guides(existing_urls)
      }
      
      import_practical_knowledge(results)
      results
    end
    
    private
    
    def get_existing_urls
      SearchableItem.where(item_type: 'practical_guide')
                    .where.not(metadata: nil)
                    .pluck(Arel.sql("metadata->>'url'"))
                    .compact
    end
    
    def research_survival_guides(existing_urls)
      puts "\n🏜️ Researching Survival Guides..."
      
      guides = []
      
      # Main survival guide
      survival_page = fetch_with_respect(@base_urls[:survival])
      if survival_page && !existing_urls.include?(@base_urls[:survival])
        puts "  📖 Analyzing main survival guide"
        
        analysis = analyze_practical_content(survival_page, @base_urls[:survival])
        
        guides << {
          title: "Official Burning Man Survival Guide",
          url: @base_urls[:survival],
          content: extract_clean_content(survival_page),
          skills: analysis[:skills],
          materials: analysis[:materials],
          warnings: analysis[:warnings],
          tips: analysis[:tips],
          difficulty_level: "essential",
          guide_type: "survival"
        }
      end
      
      # Sub-pages and specific topics
      survival_topics = [
        "water", "food", "shelter", "clothing", "bikes", "power",
        "communication", "medical", "weather", "navigation"
      ]
      
      survival_topics.each do |topic|
        url = "#{@base_urls[:playa_tech]}#{topic}/"
        next if existing_urls.include?(url)
        
        page = fetch_with_respect(url)
        next unless page
        
        analysis = analyze_practical_content(page, url)
        
        if analysis && analysis['pool_primary'] == 'practical'
          guides << {
            title: "#{topic.capitalize} Guide",
            url: url,
            content: extract_clean_content(page),
            skills: analysis['themes'] || [],
            materials: [],
            tips: [],
            guide_type: "survival_#{topic}"
          }
          puts "    ✅ Practical content identified"
        end
        
        sleep @rate_limit
      end
      
      puts "  ✅ Found #{guides.size} survival guides"
      guides
    end
    
    def research_building_techniques(existing_urls)
      puts "\n🔨 Researching Building Techniques..."
      
      building_guides = []
      
      # Common building topics
      build_topics = [
        "shade-structures", "art-installation", "camp-infrastructure",
        "lighting", "sound-systems", "generators", "solar-power"
      ]
      
      build_topics.each do |topic|
        search_url = "#{@base_urls[:building]}#{topic}/"
        next if existing_urls.include?(search_url)
        
        page = fetch_with_respect(search_url)
        next unless page
        
        # Extract building knowledge
        doc = Nokogiri::HTML(page)
        
        # Look for how-to sections
        how_to_sections = doc.css('.how-to, .instructions, .guide-content')
        
        if how_to_sections.any?
          content = how_to_sections.map(&:text).join("\n")
          
          analysis = analyze_practical_content(content, search_url)
          
          building_guides << {
            title: "Building #{topic.gsub('-', ' ').titleize}",
            url: search_url,
            content: content,
            skills: analysis[:skills],
            materials: analysis[:materials],
            tools: analysis[:tools],
            time_required: analysis[:time_estimate],
            guide_type: "building"
          }
        end
        
        sleep @rate_limit
      end
      
      building_guides
    end
    
    def research_moop_prevention(existing_urls)
      puts "\n♻️ Researching MOOP Prevention..."
      
      moop_guides = []
      
      lnt_page = fetch_with_respect(@base_urls[:leaving_no_trace])
      if lnt_page && !existing_urls.include?(@base_urls[:leaving_no_trace])
        doc = Nokogiri::HTML(lnt_page)
        
        # Extract MOOP prevention techniques
        moop_sections = doc.css('.moop-prevention, .lnt-tips, p:contains("MOOP")')
        
        if moop_sections.any?
          content = moop_sections.map(&:text).join("\n")
          
          moop_guides << {
            title: "Leave No Trace & MOOP Prevention",
            url: @base_urls[:leaving_no_trace],
            content: content,
            techniques: extract_moop_techniques(content),
            common_moop: extract_common_moop_items(content),
            guide_type: "moop_prevention"
          }
        end
      end
      
      moop_guides
    end
    
    def analyze_practical_content(html, url)
      # Use AI to determine if this is practical pool content
      # Clean the HTML first
      doc = Nokogiri::HTML(html)
      text_content = doc.text.strip
      
      # Analyze for pool classification
      @ai_service.analyze_content_for_pools(text_content, 'practical_guide')
    end
    
    def import_practical_knowledge(results)
      puts "\n💾 Importing Practical Knowledge to Database..."
      
      total_imported = 0
      
      results.each do |category, guides|
        puts "  📚 Importing #{category}: #{guides.size} items"
        
        guides.each do |guide|
          uid = generate_practical_uid(guide)
          
          item = SearchableItem.find_or_create_by(uid: uid) do |new_item|
            new_item.name = guide[:title]
            new_item.description = guide[:content]
            new_item.item_type = 'practical_guide'
            new_item.year = 2024 # Practical knowledge is timeless
            new_item.searchable_text = build_practical_searchable_text(guide)
            new_item.metadata = {
              url: guide[:url],
              guide_type: guide[:guide_type],
              skills: guide[:skills],
              materials: guide[:materials],
              tools: guide[:tools],
              warnings: guide[:warnings],
              tips: guide[:tips],
              difficulty_level: guide[:difficulty_level],
              pool_primary: 'practical',
              pool_connections: ['manifest', 'experience']
            }.compact
          end
          
          # Create practical entities
          create_practical_entities(item, guide)
          total_imported += 1
        end
      end
      
      puts "  ✅ Imported #{total_imported} practical guides"
      generate_embeddings_for_new_items
    end
    
    def create_practical_entities(item, guide)
      # Skills entities
      Array(guide[:skills]).each do |skill|
        SearchEntity.find_or_create_by(
          searchable_item: item,
          entity_type: 'pool_practical',
          entity_value: "skill: #{skill.downcase}"
        )
      end
      
      # Material entities
      Array(guide[:materials]).each do |material|
        SearchEntity.find_or_create_by(
          searchable_item: item,
          entity_type: 'pool_practical',
          entity_value: "material: #{material.downcase}"
        )
      end
      
      # Tips as entities (for searchability)
      Array(guide[:tips]).first(5).each do |tip|
        SearchEntity.find_or_create_by(
          searchable_item: item,
          entity_type: 'pool_practical',
          entity_value: tip.downcase.truncate(50)
        )
      end
    end
    
    def extract_clean_content(html)
      doc = Nokogiri::HTML(html)
      
      # Remove navigation, headers, footers
      doc.css('nav, header, footer, .navigation, .menu').remove
      
      # Get main content
      main_content = doc.css('main, .content, article').first || doc.css('body').first
      main_content&.text&.strip || html
    end
    
    def extract_moop_techniques(content)
      techniques = []
      
      # Look for bullet points or numbered lists about MOOP
      content.scan(/(?:•|\*|-|\d+\.)\s*([^•\*\-\n]+(?:MOOP|prevent|avoid|clean)[^•\*\-\n]+)/i).each do |match|
        techniques << match[0].strip
      end
      
      techniques.uniq
    end
    
    def extract_common_moop_items(content)
      # Common MOOP items mentioned in guides
      moop_items = []
      
      common_moop = [
        "glitter", "feathers", "sequins", "wood chips", "cigarette butts",
        "bottle caps", "zip ties", "duct tape", "grey water"
      ]
      
      common_moop.each do |item|
        moop_items << item if content.downcase.include?(item)
      end
      
      moop_items
    end
    
    def generate_practical_uid(guide)
      title_key = guide[:title]&.downcase&.gsub(/[^a-z0-9]/, '')&.slice(0, 30)
      "prac_#{guide[:guide_type]}_#{title_key}"
    end
    
    def build_practical_searchable_text(guide)
      parts = [
        guide[:title],
        guide[:content],
        guide[:skills]&.join(' '),
        guide[:materials]&.join(' '),
        guide[:tips]&.join(' ')
      ].compact.join(' ')
    end
    
    def generate_embeddings_for_new_items
      items = SearchableItem.where(item_type: 'practical_guide', embedding: nil)
      return if items.empty?
      
      puts "  🧠 Generating embeddings for #{items.count} practical guides..."
      embedding_service = Search::EmbeddingService.new
      
      items.find_each do |item|
        embedding = embedding_service.generate_embedding(item.searchable_text)
        item.update!(embedding: embedding) if embedding
      end
    end
    
    def fetch_with_respect(url)
      puts "    🌐 Fetching: #{url}"
      
      begin
        response = HTTParty.get(url, headers: @headers, timeout: 30)
        response.success? ? response.body : nil
      rescue => e
        puts "    ❌ Error: #{e.message}"
        nil
      end
    end
    
    # Stub methods for other practical types
    def research_weather_preparation(existing_urls)
      []
    end
    
    def research_health_safety_guides(existing_urls)
      []
    end
    
    def research_camp_setup_guides(existing_urls)
      []
    end
  end
end