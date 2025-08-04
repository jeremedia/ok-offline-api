require 'nokogiri'
require_relative 'ai_analysis_service'

module Research
  class ExperiencePoolResearcher
    include HTTParty
    
    def initialize
      @base_urls = {
        journal: "https://journal.burningman.org/",
        stories: "https://burningman.org/culture/stories/",
        voices: "https://burningman.org/voices/",
        blog: "https://journal.burningman.org/category/culture/personal-journeys/",
        transformative: "https://journal.burningman.org/category/the-burns/experiences/"
      }
      @headers = {
        'User-Agent' => 'OK-OFFLINE Research Bot 1.0 (Educational/Non-commercial)',
        'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
      }
      @rate_limit = 2.seconds
      @ai_service = ::Research::AIAnalysisService.new
    end
    
    def research_experience_pool
      puts "🎭 Starting Experience Pool Research"
      puts "=" * 60
      puts "Collecting personal stories, transformative moments, and lived experiences..."
      
      existing_urls = get_existing_urls
      puts "   Already have #{existing_urls.size} experience documents"
      
      results = {
        transformation_stories: research_transformation_stories(existing_urls),
        virgin_experiences: research_virgin_burner_stories(existing_urls),
        dust_storm_memories: research_weather_experiences(existing_urls),
        temple_experiences: research_temple_moments(existing_urls),
        sunrise_stories: research_playa_moments(existing_urls),
        connection_stories: research_human_connections(existing_urls)
      }
      
      import_experiences(results)
      results
    end
    
    private
    
    def get_existing_urls
      SearchableItem.where(item_type: 'experience_story')
                    .where.not(metadata: nil)
                    .pluck(Arel.sql("metadata->>'url'"))
                    .compact
    end
    
    def research_transformation_stories(existing_urls)
      puts "\n✨ Researching Transformation Stories..."
      
      # Search for transformation narratives
      search_urls = [
        "#{@base_urls[:journal]}?s=transformation",
        "#{@base_urls[:journal]}?s=life+changing",
        "#{@base_urls[:stories]}transformative-experiences/"
      ]
      
      stories = []
      
      search_urls.each do |search_url|
        page = fetch_with_respect(search_url)
        next unless page
        
        story_links = extract_story_links(page)
        new_links = story_links.reject { |link| existing_urls.include?(link[:url]) }
        
        new_links.first(5).each do |link|
          puts "  📖 Analyzing: #{link[:title]}"
          
          story_content = fetch_with_respect(link[:url])
          next unless story_content
          
          # Analyze for experience pool elements
          analysis = analyze_experience_content(story_content, link[:url])
          
          # Check if this is experience pool content
          if analysis && analysis['pool_primary'] == 'experience'
            stories << {
              title: link[:title],
              url: link[:url],
              content: story_content,
              emotions: analysis['themes'] || [],
              transformations: analysis['pool_connections'] || [],
              sensory_details: [],
              year_experienced: extract_year_from_content(story_content),
              author: "Burning Man Journal",
              experience_type: "transformation"
            }
            puts "    ✅ Experience pool content identified"
          else
            puts "    ⚠️  Not primarily experience content"
          end
          
          sleep @rate_limit
        end
      end
      
      puts "  ✅ Found #{stories.size} transformation stories"
      stories
    end
    
    def research_virgin_burner_stories(existing_urls)
      puts "\n🌟 Researching Virgin Burner Experiences..."
      
      # These are gold for understanding first encounters with principles
      virgin_stories = []
      
      search_terms = ["first burn", "virgin burner", "first time", "newbie"]
      
      search_terms.each do |term|
        url = "#{@base_urls[:journal]}?s=#{term.gsub(' ', '+')}"
        page = fetch_with_respect(url)
        next unless page
        
        links = extract_story_links(page)
        new_links = links.reject { |link| existing_urls.include?(link[:url]) }
        
        new_links.first(3).each do |link|
          content = fetch_with_respect(link[:url])
          next unless content
          
          analysis = analyze_experience_content(content, link[:url])
          
          if analysis && (analysis['pool_primary'] == 'experience' || 
                         analysis['themes']&.any? { |t| t =~ /first|virgin|new/i })
            virgin_stories << {
              title: link[:title],
              url: link[:url],
              content: content,
              first_impressions: analysis['themes'] || [],
              principle_encounters: analysis['principles'] || [],
              experience_type: "virgin_burn"
            }
          end
          
          sleep @rate_limit
        end
      end
      
      virgin_stories
    end
    
    def research_temple_moments(existing_urls)
      puts "\n🏛️ Researching Temple Experiences..."
      
      # Temple experiences are deeply emotional and transformative
      temple_stories = []
      
      temple_urls = [
        "#{@base_urls[:journal]}?s=temple+grief",
        "#{@base_urls[:journal]}?s=temple+ceremony",
        "#{@base_urls[:journal]}?s=temple+burn+emotional"
      ]
      
      temple_urls.each do |url|
        page = fetch_with_respect(url)
        next unless page
        
        links = extract_story_links(page)
        # Process temple stories...
      end
      
      temple_stories
    end
    
    def analyze_experience_content(html, url)
      # Use AI to determine if this is experience pool content
      # Clean the HTML first
      doc = Nokogiri::HTML(html)
      text_content = doc.text.strip
      
      # Analyze for pool classification
      @ai_service.analyze_content_for_pools(text_content, 'experience_story')
    end
    
    def import_experiences(results)
      puts "\n💾 Importing Experience Stories to Database..."
      
      total_imported = 0
      
      results.each do |category, stories|
        puts "  📚 Importing #{category}: #{stories.size} items"
        
        stories.each do |story|
          uid = generate_experience_uid(story)
          
          item = SearchableItem.find_or_create_by(uid: uid) do |new_item|
            new_item.name = story[:title]
            new_item.description = story[:content]
            new_item.item_type = 'experience_story'
            new_item.year = story[:year_experienced] || extract_year_from_content(story[:content])
            new_item.searchable_text = build_searchable_text(story)
            new_item.metadata = {
              author: story[:author],
              url: story[:url],
              experience_type: story[:experience_type],
              emotions: story[:emotions],
              transformations: story[:transformations],
              sensory_details: story[:sensory_details],
              pool_primary: 'experience',
              pool_connections: ['idea', 'relational', 'manifest']
            }.compact
          end
          
          # Create pool entities
          create_experience_entities(item, story)
          total_imported += 1
        end
      end
      
      puts "  ✅ Imported #{total_imported} experience stories"
      generate_embeddings_for_new_items
    end
    
    def create_experience_entities(item, story)
      # Extract emotion entities
      Array(story[:emotions]).each do |emotion|
        SearchEntity.find_or_create_by(
          searchable_item: item,
          entity_type: 'pool_experience',
          entity_value: emotion.downcase
        )
      end
      
      # Extract transformation entities
      Array(story[:transformations]).each do |transformation|
        SearchEntity.find_or_create_by(
          searchable_item: item,
          entity_type: 'pool_experience',
          entity_value: "transformation: #{transformation.downcase}"
        )
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
    
    def extract_story_links(html)
      doc = Nokogiri::HTML(html)
      links = []
      
      # Common patterns for story/article links
      doc.css('article a, .post-title a, h2 a, h3 a').each do |link|
        href = link['href']
        next unless href && href.include?('journal.burningman.org')
        
        links << {
          url: href,
          title: link.text.strip
        }
      end
      
      links.uniq { |l| l[:url] }
    end
    
    def generate_experience_uid(story)
      title_key = story[:title]&.downcase&.gsub(/[^a-z0-9]/, '')&.slice(0, 30)
      "exp_#{story[:experience_type]}_#{title_key}"
    end
    
    def build_searchable_text(story)
      parts = [
        story[:title],
        story[:content],
        story[:emotions]&.join(' '),
        story[:transformations]&.join(' '),
        story[:sensory_details]&.join(' ')
      ].compact.join(' ')
    end
    
    def generate_embeddings_for_new_items
      items = SearchableItem.where(item_type: 'experience_story', embedding: nil)
      return if items.empty?
      
      puts "  🧠 Generating embeddings for #{items.count} experience stories..."
      embedding_service = Search::EmbeddingService.new
      
      items.find_each do |item|
        embedding = embedding_service.generate_embedding(item.searchable_text)
        item.update!(embedding: embedding) if embedding
      end
    end
    
    # Stub methods for other experience types
    def research_weather_experiences(existing_urls)
      []
    end
    
    def research_playa_moments(existing_urls)
      []
    end
    
    def research_human_connections(existing_urls)
      []
    end
    
    def extract_year_from_content(content)
      content&.scan(/\b(20\d{2})\b/)&.map(&:first)&.map(&:to_i)&.max || 2024
    end
  end
end