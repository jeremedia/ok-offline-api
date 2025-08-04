namespace :research do
  desc "Research and import philosophical texts for the Idea Pool"
  task philosophical_texts: :environment do
    # Load research services
    require_relative '../../app/services/research/ai_analysis_service'
    puts "🧠 Starting Philosophical Text Research for Enliteracy"
    puts "=" * 60
    puts "This will use AI to intelligently analyze and extract"
    puts "Burning Man philosophical content for the Idea Pool."
    puts
    
    # Check prerequisites
    unless ENV['OPENAI_API_KEY']
      puts "❌ OPENAI_API_KEY environment variable not set!"
      puts "   This is required for intelligent analysis."
      exit 1
    end
    
    begin
      researcher = Research::PhilosophicalTextResearcher.new
      
      puts "🔬 Initializing intelligent research with AI Analysis Service..."
      puts "   Rate limited to 2 seconds between requests"
      puts "   Each page will be analyzed by AI for philosophical content"
      puts
      
      start_time = Time.current
      
      # Research the Idea Pool
      results = researcher.research_idea_pool
      
      end_time = Time.current
      duration = ((end_time - start_time) / 60).round(1)
      
      puts
      puts "✅ Research Complete!"
      puts "   Duration: #{duration} minutes"
      puts "   Categories researched:"
      
      total_texts = 0
      results.each do |category, texts|
        count = texts.is_a?(Array) ? texts.size : 0
        total_texts += count
        puts "     #{category}: #{count} items"
      end
      
      puts "   Total philosophical texts: #{total_texts}"
      puts
      
      if total_texts > 0
        puts "📊 Enhanced Analysis Summary:"
        puts "   - Each text analyzed for pool connections"
        puts "   - Entities extracted and cross-referenced"
        puts "   - Principles and themes identified"
        puts "   - Historical significance assessed"
        puts "   - Flows between pools mapped"
        puts
        puts "🎯 Idea Pool Status: ENRICHED"
        puts "   The dataset now has foundational philosophical content"
        puts "   enabling true enliteracy with principle-to-manifestation flows."
      else
        puts "⚠️  No philosophical texts found. Check network connectivity"
        puts "   and ensure burningman.org is accessible."
      end
      
    rescue => e
      puts "❌ Research failed: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      exit 1
    end
  end
  
  desc "Check philosophical text research prerequisites"
  task check_prereqs: :environment do
    puts "🔍 Checking Philosophical Text Research Prerequisites"
    puts "=" * 50
    
    # Check OpenAI API
    if ENV['OPENAI_API_KEY']
      key_preview = ENV['OPENAI_API_KEY'][0..10] + "..."
      puts "✅ OPENAI_API_KEY: #{key_preview}"
    else
      puts "❌ OPENAI_API_KEY: Not set"
    end
    
    
    # Check network connectivity
    begin
      require 'net/http'
      uri = URI('https://burningman.org')
      response = Net::HTTP.get_response(uri)
      if response.code == '200'
        puts "✅ Network: burningman.org accessible"
      else
        puts "⚠️  Network: burningman.org returned #{response.code}"
      end
    rescue => e
      puts "❌ Network: Cannot reach burningman.org (#{e.message})"
    end
    
    # Check current philosophical texts
    phil_count = SearchableItem.where(item_type: 'philosophical_text').count
    puts "📚 Current philosophical texts: #{phil_count}"
    
    if phil_count > 0
      puts "   Recent additions:"
      SearchableItem.where(item_type: 'philosophical_text')
                   .order(created_at: :desc)
                   .limit(3)
                   .each do |item|
        puts "     - #{item.name} (#{item.year})"
      end
    end
    
    puts
    puts "Ready to research!" if ENV['OPENAI_API_KEY']
  end
  
  desc "Preview philosophical research targets"
  task preview_targets: :environment do
    puts "🎯 Philosophical Text Research Targets"
    puts "=" * 50
    
    base_urls = {
      philosophical_center: "https://burningman.org/programs/philosophical-center/",
      journal: "https://journal.burningman.org/",
      founders_voices: "https://burningman.org/programs/philosophical-center/founders-voices/",
      ten_principles: "https://burningman.org/programs/philosophical-center/ten-principles/",
      historical_pubs: "https://burningman.org/culture/history/historical-publications/"
    }
    
    puts "🥇 HIGH PRIORITY (Foundation):"
    puts "   1. Larry Harvey Essays"
    puts "      Source: #{base_urls[:founders_voices]}"
    puts "      Focus: Foundational philosophy and vision"
    puts
    puts "   2. Ten Principles Content"
    puts "      Source: #{base_urls[:ten_principles]}"
    puts "      Focus: Core principles with explanations"
    puts
    puts "   3. Philosophical Center"
    puts "      Source: #{base_urls[:philosophical_center]}"
    puts "      Focus: Contemporary philosophical development"
    puts
    puts "   4. Burning Man Journal"
    puts "      Source: #{base_urls[:journal]}"
    puts "      Focus: Community discourse and reflection"
    puts
    puts "🥈 MEDIUM PRIORITY (Historical):"
    puts "   5. Historical Publications"
    puts "      Source: #{base_urls[:historical_pubs]}"
    puts "      Focus: Building Burning Man newsletters, AfterBurn reports"
    puts
    puts "🧠 AI ENHANCEMENT:"
    puts "   - Each page analyzed by AI for philosophical significance"
    puts "   - Content structured and cross-referenced"
    puts "   - Pool connections identified and mapped"
    puts "   - Entities extracted and normalized"
    puts "   - Historical context and influence assessed"
    puts
    puts "Run 'rake research:philosophical_texts' to begin research!"
  end
end