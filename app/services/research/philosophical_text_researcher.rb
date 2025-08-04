require 'nokogiri'

module Research
  class PhilosophicalTextResearcher
    include HTTParty
    
    def initialize
      @base_urls = {
        philosophical_center: "https://burningman.org/programs/philosophical-center/",
        journal: "https://journal.burningman.org/",
        founders_voices: "https://burningman.org/programs/philosophical-center/founders-voices/",
        ten_principles: "https://burningman.org/programs/philosophical-center/ten-principles/",
        historical_pubs: "https://burningman.org/culture/history/historical-publications/"
      }
      @headers = {
        'User-Agent' => 'OK-OFFLINE Research Bot 1.0 (Educational/Non-commercial)',
        'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
      }
      @rate_limit = 2.seconds # Respectful crawling
      @ai_service = Research::AIAnalysisService.new
    end
    
    def research_idea_pool
      puts "🔬 Starting Philosophical Text Research for Idea Pool"
      puts "=" * 60
      
      # Track what we've already processed to avoid duplicates
      puts "📊 Checking existing philosophical texts..."
      existing_urls = get_existing_urls
      puts "   Already have #{existing_urls.size} documents"
      
      results = {
        larry_harvey_essays: research_larry_harvey_writings(existing_urls),
        ten_principles: research_ten_principles_content(existing_urls),
        theme_rationales: research_annual_themes(existing_urls),
        philosophical_center: research_philosophical_center(existing_urls),
        journal_articles: research_journal_articles(existing_urls),
        afterburn_reports: research_afterburn_reports(existing_urls),
        building_bm_newsletters: research_historical_newsletters(existing_urls)
      }
      
      # Import findings into database
      import_philosophical_texts(results)
      
      results
    end
    
    private
    
    def get_existing_urls
      SearchableItem.where(item_type: 'philosophical_text')
                    .where.not(metadata: nil)
                    .pluck(Arel.sql("metadata->>'url'"))
                    .compact
    end
    
    def research_larry_harvey_writings(existing_urls = [])
      puts "\n📖 Researching Larry Harvey Essays..."
      
      # Start with main Larry Harvey page
      larry_page = fetch_with_respect("#{@base_urls[:founders_voices]}larry-harvey/")
      return [] unless larry_page
      
      # Use Claude to intelligently extract essay links
      essay_links = @ai_service.extract_essay_links_from_page(
        "#{@base_urls[:founders_voices]}larry-harvey/", 
        larry_page
      )
      
      # Research Journal articles by Larry (placeholder for now)
      journal_links = []
      all_links = essay_links + journal_links
      
      # Filter out URLs we've already processed
      new_links = all_links.reject { |link| existing_urls.include?(link['url'] || link[:url]) }
      puts "  📊 Found #{all_links.size} total links, #{new_links.size} new"
      
      essays = []
      
      new_links.each do |link|
        puts "  📄 Analyzing: #{link['title'] || link[:title]}"
        
        content_html = fetch_with_respect(link['url'] || link[:url])
        next unless content_html
        
        # Use Claude to analyze and extract the philosophical content
        analysis = @ai_service.analyze_webpage_for_philosophical_content(
          link['url'] || link[:url], 
          content_html
        )
        
        next unless analysis['extract_worthy']
        
        # Extract structured content using Claude
        structured_content = @ai_service.extract_structured_content(
          content_html, 
          analysis['content_type']
        )
        
        # Analyze which pools this content connects to
        pool_analysis = @ai_service.analyze_content_for_pools(
          structured_content['content'], 
          'philosophical_text'
        )
        
        essays << {
          title: structured_content['title'],
          url: link['url'] || link[:url],
          content: structured_content['content'],
          author: structured_content['author'] || "Larry Harvey",
          source: "Philosophical Center",
          estimated_year: structured_content['estimated_year'],
          content_type: "foundational_essay",
          metadata: structured_content['metadata'],
          pool_analysis: pool_analysis,
          searchable_text: structured_content['searchable_text'],
          claude_analysis: analysis
        }
        
        sleep @rate_limit
      end
      
      puts "  ✅ Found #{essays.size} new Larry Harvey essays"
      essays
    end
    
    def research_ten_principles_content(existing_urls = [])
      puts "\n⚖️ Researching 10 Principles Content..."
      
      principles_page = fetch_with_respect(@base_urls[:ten_principles])
      return [] unless principles_page
      
      # Skip if we've already processed the ten principles page
      if existing_urls.include?(@base_urls[:ten_principles])
        puts "  📊 Ten Principles page already processed"
        return []
      end
      
      principles = extract_principles_with_explanations(principles_page)
      
      principles.map do |principle|
        {
          title: "The Principle of #{principle[:name]}",
          url: @base_urls[:ten_principles],
          content: principle[:explanation],
          author: "Burning Man Project",
          source: "Ten Principles",
          principle_name: principle[:name],
          content_type: "core_principle"
        }
      end
    end
    
    def research_annual_themes(existing_urls = [])
      puts "\n🎭 Researching Annual Theme Rationales..."
      
      # This would research theme pages, looking for philosophical explanations
      # of why each year's theme was chosen and what it means
      themes = []
      
      (1986..2025).each do |year|
        theme_info = research_year_theme(year, existing_urls)
        if theme_info
          themes << {
            title: "#{year} Theme: #{theme_info[:theme]}",
            url: theme_info[:url],
            content: theme_info[:rationale],
            year: year,
            theme_name: theme_info[:theme],
            author: theme_info[:author] || "Burning Man Project",
            source: "Annual Themes",
            content_type: "theme_rationale"
          }
        end
      end
      
      puts "  ✅ Found #{themes.size} new theme rationales"
      themes
    end
    
    def research_philosophical_center(existing_urls = [])
      puts "\n🏛️ Researching Philosophical Center Content..."
      
      # Research all philosophical center pages for foundational content
      phil_center_page = fetch_with_respect(@base_urls[:philosophical_center])
      return [] unless phil_center_page
      
      philosophical_links = extract_philosophical_links(phil_center_page)
      new_links = philosophical_links.reject { |link| existing_urls.include?(link[:url]) }
      puts "  📊 Found #{philosophical_links.size} total links, #{new_links.size} new"
      
      philosophical_texts = []
      
      new_links.each do |link|
        content = fetch_essay_content(link[:url])
        
        philosophical_texts << {
          title: link[:title],
          url: link[:url],
          content: content,
          source: "Philosophical Center",
          content_type: "philosophical_content"
        }
        
        sleep @rate_limit
      end
      
      puts "  ✅ Found #{philosophical_texts.size} new philosophical center texts"
      philosophical_texts
    end
    
    def research_afterburn_reports(existing_urls = [])
      puts "\n🔥 Researching AfterBurn Reports..."
      
      # AfterBurn reports contain community reflection and are crucial
      # for understanding the Experience and Evolutionary pools as well
      afterburn_links = find_afterburn_reports
      new_links = afterburn_links.reject { |link| existing_urls.include?(link[:url]) }
      puts "  📊 Found #{afterburn_links.size} total reports, #{new_links.size} new"
      
      reports = []
      
      new_links.each do |link|
        content = fetch_pdf_or_html_content(link[:url])
        
        reports << {
          title: "AfterBurn Report #{link[:year]}",
          url: link[:url],
          content: content,
          year: link[:year],
          source: "AfterBurn Reports",
          content_type: "community_reflection"
        }
        
        sleep @rate_limit
      end
      
      puts "  ✅ Found #{reports.size} new AfterBurn reports"
      reports
    end
    
    def research_historical_newsletters(existing_urls = [])
      puts "\n📰 Researching Historical Newsletters..."
      
      # Building Burning Man newsletters (1991-1999) contain early philosophy
      historical_page = fetch_with_respect(@base_urls[:historical_pubs])
      return [] unless historical_page
      
      newsletter_links = extract_newsletter_links(historical_page)
      new_links = newsletter_links.reject { |link| existing_urls.include?(link[:url]) }
      puts "  📊 Found #{newsletter_links.size} total newsletters, #{new_links.size} new"
      
      newsletters = []
      
      new_links.each do |link|
        content = fetch_pdf_or_html_content(link[:url])
        
        newsletters << {
          title: link[:title],
          url: link[:url],
          content: content,
          year: link[:year],
          source: "Building Burning Man Newsletter",
          content_type: "historical_newsletter"
        }
        
        sleep @rate_limit
      end
      
      puts "  ✅ Found #{newsletters.size} new historical newsletters"
      newsletters
    end
    
    def research_journal_articles(existing_urls = [])
      puts "\n📚 Researching Burning Man Journal Articles..."
      
      # The Burning Man Journal contains philosophical essays and deep reflections
      journal_base = "https://journal.burningman.org"
      
      # Try to get recent articles from the journal
      journal_page = fetch_with_respect(journal_base)
      return [] unless journal_page
      
      # Extract article links from the journal
      article_links = extract_journal_article_links(journal_page)
      new_links = article_links.reject { |link| existing_urls.include?(link[:url]) }
      puts "  📊 Found #{article_links.size} total articles, #{new_links.size} new"
      
      articles = []
      
      new_links.first(10).each do |link|  # Limit to 10 articles per run
        puts "  📄 Analyzing: #{link[:title]}"
        
        article_content = fetch_with_respect(link[:url])
        if article_content
          # Use Claude to analyze the article
          analysis = @ai_service.analyze_content_for_pools(article_content, 'journal_article')
          
          # Include articles that have a primary pool assignment
          if analysis && analysis['pool_primary']
            articles << {
              title: link[:title],
              url: link[:url],
              content: article_content,  # Use raw content since analysis doesn't return content
              author: link[:author] || "Burning Man Journal",
              source: "Burning Man Journal",
              pool_primary: analysis['pool_primary'],
              pool_connections: analysis['pool_connections'],
              themes: analysis['themes'],
              principles: analysis['principles'],
              content_type: "journal_article"
            }
            puts "    ✅ Primary pool: #{analysis['pool_primary']}"
          else
            puts "    ⚠️  Could not determine pool assignment"
          end
        end
        
        sleep @rate_limit
      end
      
      puts "  ✅ Found #{articles.size} new journal articles"
      articles
    end
    
    def fetch_with_respect(url)
      puts "    🌐 Fetching: #{url}"
      
      begin
        response = HTTParty.get(url, headers: @headers, timeout: 30)
        
        if response.success?
          response.body
        else
          puts "    ❌ Failed to fetch #{url}: #{response.code}"
          nil
        end
      rescue => e
        puts "    ❌ Error fetching #{url}: #{e.message}"
        nil
      end
    end
    
    def extract_essay_links(html)
      # Extract links to actual essays from Larry Harvey page
      # This would use Nokogiri to parse HTML and find essay links
      []
    end
    
    def extract_year_from_content(content)
      # Try to determine when essay was written from content/context
      content&.scan(/\b(19|20)\d{2}\b/)&.last&.first&.to_i
    end
    
    def import_philosophical_texts(research_results)
      puts "\n💾 Importing Philosophical Texts to Database..."
      
      total_imported = 0
      
      research_results.each do |category, texts|
        puts "  📚 Importing #{category}: #{texts.size} items"
        
        texts.each do |text|
          # Use the enhanced searchable_text if Claude provided it
          searchable_content = text[:searchable_text] || "#{text[:title]} #{text[:content]}"
          
          uid = generate_philosophical_text_uid(text)
          
          # Use find_or_create to avoid duplicates
          item = SearchableItem.find_or_create_by(uid: uid) do |new_item|
            new_item.name = text[:title]
            new_item.description = text[:content]
            new_item.item_type = 'philosophical_text'
            new_item.year = text[:year] || text[:estimated_year] || extract_year_from_title(text[:title])
            new_item.searchable_text = searchable_content
            new_item.metadata = {
              author: text[:author],
              source: text[:source],
              content_type: text[:content_type],
              url: text[:url],
              principle_name: text[:principle_name],
              theme_name: text[:theme_name],
              # Enhanced metadata from Claude analysis
              pool_primary: text.dig(:pool_analysis, 'pool_primary'),
              pool_connections: text.dig(:pool_analysis, 'pool_connections'),
              themes_explored: text.dig(:metadata, 'themes_explored'),
              principles_embodied: text.dig(:metadata, 'principles_embodied'),
              historical_significance: text.dig(:metadata, 'historical_significance'),
              key_concepts: text.dig(:metadata, 'key_concepts'),
              claude_confidence: text.dig(:claude_analysis, 'significance'),
              flows: text.dig(:pool_analysis, 'flows')
            }.compact
          end
          
          # Create SearchEntity records for enhanced entities
          if text[:pool_analysis] && text[:pool_analysis]['entities']
            entities = text[:pool_analysis]['entities']
            
            entities.each do |entity_type, entity_list|
              Array(entity_list).each do |entity_value|
                SearchEntity.find_or_create_by(
                  searchable_item: item,
                  entity_type: entity_type.singularize,
                  entity_value: entity_value
                )
              end
            end
          end
          
          total_imported += 1
        end
      end
      
      puts "  ✅ Imported #{total_imported} philosophical texts with enhanced metadata"
      
      # Generate embeddings for new texts
      puts "  🧠 Generating embeddings for philosophical texts..."
      philosophical_items = SearchableItem.where(item_type: 'philosophical_text', embedding: nil)
      
      if philosophical_items.any?
        embedding_service = Search::EmbeddingService.new
        philosophical_items.find_each do |item|
          embedding = embedding_service.generate_embedding(item.searchable_text)
          item.update!(embedding: embedding) if embedding
        end
        
        puts "  ✅ Generated embeddings for #{philosophical_items.count} texts"
      end
      
      puts "  🎯 Philosophical Text Research Complete!"
      puts "     Enhanced with pool analysis and cross-connections"
    end
    
    def extract_year_from_title(title)
      title&.scan(/\b(19|20)\d{2}\b/)&.first&.first&.to_i || 2024
    end
    
    # Placeholder methods to implement later
    def extract_principles_with_explanations(html)
      return [] unless html
      
      doc = Nokogiri::HTML(html)
      principles = []
      
      # The 10 Principles in order
      principle_names = [
        "Radical Inclusion", "Gifting", "Decommodification", "Radical Self-reliance",
        "Radical Self-expression", "Communal Effort", "Civic Responsibility",
        "Leaving No Trace", "Participation", "Immediacy"
      ]
      
      # Look for principle sections
      principle_names.each do |principle_name|
        # Try to find the principle's section and explanation
        principle_section = doc.xpath("//h2[contains(text(), '#{principle_name}')]").first ||
                           doc.xpath("//h3[contains(text(), '#{principle_name}')]").first
        
        if principle_section
          # Get the explanation text following the heading
          explanation = ""
          current = principle_section.next_element
          
          while current && !current.name.match(/^h[123]$/)
            explanation += current.text.strip + " "
            current = current.next_element
          end
          
          principles << {
            name: principle_name,
            explanation: explanation.strip
          } unless explanation.empty?
        end
      end
      
      # If we didn't find structured principles, try to extract from unstructured text
      if principles.empty?
        content = doc.text
        principle_names.each do |principle_name|
          if content.include?(principle_name)
            # Extract a paragraph around the principle mention
            index = content.index(principle_name)
            start_index = [0, index - 200].max
            end_index = [content.length, index + 500].min
            explanation = content[start_index..end_index].strip
            
            principles << {
              name: principle_name,
              explanation: explanation
            }
          end
        end
      end
      
      principles
    end
    
    def research_year_theme(year, existing_urls = [])
      # Check if we've already processed this year's theme
      theme_url = "https://burningman.org/event/brc/#{year}-event/#{year}-art-theme/"
      return nil if existing_urls.include?(theme_url)
      
      # Placeholder - would fetch and analyze theme page
      nil
    end
    
    def extract_philosophical_links(html)
      return [] unless html
      
      doc = Nokogiri::HTML(html)
      links = []
      
      # Look for links to philosophical content
      doc.css('a[href*="philosophical"], a[href*="philosophy"], a[href*="essay"]').each do |link|
        href = link['href']
        next unless href
        
        # Make relative URLs absolute
        full_url = href.start_with?('/') ? "https://burningman.org#{href}" : href
        
        links << {
          url: full_url,
          title: link.text.strip
        }
      end
      
      links.uniq { |l| l[:url] }
    end
    
    def find_afterburn_reports
      reports = []
      
      # Known pattern for AfterBurn report URLs
      # These are typically PDF reports published after each event
      base_afterburn_url = "https://burningman.org/event/preparation/afterburn/"
      
      # Try to fetch the AfterBurn archive page
      afterburn_page = fetch_with_respect(base_afterburn_url)
      if afterburn_page
        doc = Nokogiri::HTML(afterburn_page)
        
        # Look for AfterBurn report links
        doc.css('a[href*="afterburn"][href$=".pdf"], a[href*="AfterBurn"]').each do |link|
          href = link['href']
          next unless href
          
          # Extract year from URL or link text
          year_match = href.match(/(19|20)\d{2}/) || link.text.match(/(19|20)\d{2}/)
          year = year_match ? year_match[0].to_i : nil
          
          reports << {
            url: href.start_with?('/') ? "https://burningman.org#{href}" : href,
            year: year,
            title: link.text.strip
          }
        end
      end
      
      # Add known AfterBurn reports that might not be linked
      (2010..2023).each do |year|
        # Common patterns for AfterBurn URLs
        potential_urls = [
          "https://burningman.org/wp-content/uploads/#{year}-AfterBurn-Report.pdf",
          "https://burningman.org/event/preparation/afterburn/#{year}-afterburn-report/"
        ]
        
        potential_urls.each do |url|
          unless reports.any? { |r| r[:year] == year }
            reports << {
              url: url,
              year: year,
              title: "AfterBurn Report #{year}"
            }
          end
        end
      end
      
      reports.uniq { |r| r[:year] }.sort_by { |r| r[:year] }.reverse
    end
    
    def extract_newsletter_links(html)
      return [] unless html
      
      doc = Nokogiri::HTML(html)
      links = []
      
      # Look for PDF and HTML newsletter links
      doc.css('a[href$=".pdf"], a[href*="newsletter"]').each do |link|
        href = link['href']
        next unless href
        
        # Extract year from link text or URL
        year_match = link.text.match(/(19|20)\d{2}/) || href.match(/(19|20)\d{2}/)
        year = year_match ? year_match[0].to_i : nil
        
        links << {
          url: href.start_with?('/') ? "https://burningman.org#{href}" : href,
          title: link.text.strip,
          year: year
        }
      end
      
      links.uniq { |l| l[:url] }
    end
    
    def extract_journal_article_links(html)
      return [] unless html
      
      doc = Nokogiri::HTML(html)
      links = []
      
      # Look for article links in common patterns
      doc.css('article a, .post-title a, .entry-title a, h2 a, h3 a').each do |link|
        href = link['href']
        next unless href && (href.include?('journal.burningman.org') || href.start_with?('/'))
        
        # Make relative URLs absolute
        full_url = href.start_with?('/') ? "https://journal.burningman.org#{href}" : href
        
        # Skip non-article pages
        next if full_url.include?('category') || full_url.include?('tag') || full_url.include?('author')
        
        links << {
          url: full_url.strip,
          title: link.text.strip,
          author: extract_author_from_article(link)
        }
      end
      
      links.uniq { |l| l[:url] }
    end
    
    def extract_author_from_article(link_element)
      # Try to find author info near the article link
      parent = link_element.parent
      author_element = parent&.css('.author, .by-author, .post-author')&.first
      author_element ? author_element.text.strip.gsub(/^by\s+/i, '') : nil
    end
    
    def fetch_pdf_or_html_content(url)
      fetch_with_respect(url)
    end
    
    def fetch_essay_content(url)
      fetch_with_respect(url)
    end
    
    def generate_philosophical_text_uid(text)
      # Generate unique ID based on title and source
      source_key = text[:source]&.downcase&.gsub(/[^a-z0-9]/, '') || 'unknown'
      title_key = text[:title]&.downcase&.gsub(/[^a-z0-9]/, '')&.slice(0, 30) || 'untitled'
      year = text[:year] || text[:estimated_year] || 2024
      
      "phil_#{source_key}_#{year}_#{title_key}"
    end
  end
end