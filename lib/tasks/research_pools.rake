namespace :research do
  desc "Research all seven pools in parallel"
  task all_pools: :environment do
    puts "🌊 Researching All Seven Pools of Enliteracy"
    puts "=" * 60
    
    # Check prerequisites
    unless ENV['OPENAI_API_KEY']
      puts "❌ OPENAI_API_KEY required for AI analysis"
      exit 1
    end
    
    results = {}
    
    # 1. Idea Pool (Philosophical texts)
    puts "\n1️⃣ IDEA POOL"
    begin
      researcher = Research::PhilosophicalTextResearcher.new
      results[:idea] = researcher.research_idea_pool
    rescue => e
      puts "   ❌ Error: #{e.message}"
      results[:idea] = { error: e.message }
    end
    
    # 2. Experience Pool (Stories and emotions)
    puts "\n2️⃣ EXPERIENCE POOL"
    begin
      researcher = Research::ExperiencePoolResearcher.new
      results[:experience] = researcher.research_experience_pool
    rescue => e
      puts "   ❌ Error: #{e.message}"
      results[:experience] = { error: e.message }
    end
    
    # 3. Practical Pool (How-to knowledge)
    puts "\n3️⃣ PRACTICAL POOL"
    begin
      researcher = Research::PracticalPoolResearcher.new
      results[:practical] = researcher.research_practical_pool
    rescue => e
      puts "   ❌ Error: #{e.message}"
      results[:practical] = { error: e.message }
    end
    
    # Note: Other pools would need researchers:
    # - Relational Pool (connections between entities)
    # - Evolutionary Pool (changes over time)
    # - Emanation Pool (regional/global impact)
    # These might be better served by analysis of existing data
    
    puts "\n📊 Research Summary"
    puts "=" * 60
    
    results.each do |pool, data|
      if data[:error]
        puts "#{pool.to_s.upcase}: ❌ Error - #{data[:error]}"
      else
        total_items = data.values.select { |v| v.is_a?(Array) }.sum(&:size)
        puts "#{pool.to_s.upcase}: ✅ #{total_items} items imported"
      end
    end
    
    # Show pool entity counts
    puts "\n🏊 Pool Entity Counts:"
    %w[idea manifest experience relational evolutionary practical emanation].each do |pool|
      count = SearchEntity.where(entity_type: "pool_#{pool}").count
      items = SearchableItem.joins(:search_entities)
                           .where(search_entities: { entity_type: "pool_#{pool}" })
                           .distinct.count
      puts "  #{pool.capitalize}: #{count} entities across #{items} items"
    end
    
    puts "\n✅ Pool research complete!"
  end
  
  desc "Research a specific pool"
  task :pool, [:pool_name] => :environment do |t, args|
    pool_name = args.pool_name&.downcase
    
    unless %w[idea experience practical relational evolutionary emanation].include?(pool_name)
      puts "❌ Invalid pool name. Choose from: idea, experience, practical, relational, evolutionary, emanation"
      exit 1
    end
    
    case pool_name
    when 'idea'
      Research::PhilosophicalTextResearcher.new.research_idea_pool
    when 'experience'
      Research::ExperiencePoolResearcher.new.research_experience_pool
    when 'practical'
      Research::PracticalPoolResearcher.new.research_practical_pool
    else
      puts "❌ Researcher not yet implemented for #{pool_name} pool"
    end
  end
  
  desc "Show pool research status"
  task pool_status: :environment do
    puts "🌊 Seven Pools Research Status"
    puts "=" * 60
    
    pools = {
      idea: { 
        types: ['philosophical_text'],
        researcher: 'PhilosophicalTextResearcher'
      },
      manifest: {
        types: ['camp', 'art', 'event', 'infrastructure'],
        researcher: 'Built-in (already imported)'
      },
      experience: {
        types: ['experience_story'],
        researcher: 'ExperiencePoolResearcher'
      },
      relational: {
        types: [],
        researcher: 'Not yet built (use entity extraction)'
      },
      evolutionary: {
        types: ['timeline_event', 'historical_fact'],
        researcher: 'Built from year data'
      },
      practical: {
        types: ['practical_guide'],
        researcher: 'PracticalPoolResearcher'
      },
      emanation: {
        types: ['regional_impact'],
        researcher: 'Not yet built'
      }
    }
    
    pools.each do |pool, info|
      puts "\n#{pool.to_s.upcase} POOL:"
      puts "  Researcher: #{info[:researcher]}"
      
      if info[:types].any?
        info[:types].each do |type|
          count = SearchableItem.where(item_type: type).count
          puts "  #{type}: #{count} items"
        end
      end
      
      # Pool entities
      entity_count = SearchEntity.where(entity_type: "pool_#{pool}").count
      puts "  Pool entities: #{entity_count}"
    end
    
    # Cross-pool flows
    flow_count = SearchEntity.where(entity_type: 'flow').count
    puts "\nCROSS-POOL FLOWS: #{flow_count}"
    
    # Overall coverage
    total_items = SearchableItem.count
    items_with_pools = SearchableItem.joins(:search_entities)
                                    .where('search_entities.entity_type LIKE ?', 'pool_%')
                                    .distinct.count
    
    puts "\nOVERALL COVERAGE:"
    puts "  Total items: #{total_items}"
    puts "  Items with pool entities: #{items_with_pools} (#{(items_with_pools.to_f / total_items * 100).round(1)}%)"
  end
end