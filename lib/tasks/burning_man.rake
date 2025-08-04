namespace :burning_man do
  desc "Seed historical data for a specific year"
  task :seed_year, [:year] => :environment do |t, args|
    year = args[:year]&.to_i
    
    unless year && year.between?(1986, 2025)
      puts "❌ Please provide a valid year between 1986 and 2025"
      puts "   Usage: rails burning_man:seed_year[2003]"
      exit 1
    end
    
    # Load the index
    require Rails.root.join("db/seeds/burning_man_years_index.rb")
    
    if BURNING_MAN_YEARS[year]
      puts "🔥 Seeding Burning Man #{year}..."
      seed_year(year)
      puts "✅ Done!"
    else
      puts "❌ No data configured for year #{year}"
    end
  end
  
  desc "Seed all completed historical years"
  task seed_all: :environment do
    puts "🔥 Seeding all completed Burning Man years..."
    
    # Load the index
    require Rails.root.join("db/seeds/burning_man_years_index.rb")
    
    seed_all_complete_years
    
    puts "\n✅ All completed years have been seeded!"
    show_seed_progress
  end
  
  desc "Show seed progress"
  task progress: :environment do
    require Rails.root.join("db/seeds/burning_man_years_index.rb")
    show_seed_progress
  end
  
  desc "Import infrastructure.json for all years"
  task import_infrastructure: :environment do
    puts "🏗️  Importing infrastructure data..."
    
    # Load infrastructure.json
    infra_path = Rails.root.join("..", "frontend", "src", "data", "infrastructure.json")
    infrastructure_data = JSON.parse(File.read(infra_path))
    
    infrastructure_data["infrastructure"].each do |infra|
      puts "\n📍 Processing: #{infra['name']}"
      
      # Determine which years this infrastructure exists
      # Based on timeline data in the infrastructure.json
      start_year = case infra["id"]
      when "the-man" then 1986
      when "temple" then 2000
      when "center-camp" then 1995
      when "airport" then 1997
      when "medical" then 1992
      when "rangers" then 1992
      when "dpw" then 1998
      when "arctica" then 1997
      when "dmz" then 2006
      when "hell-station" then 2001
      when "facilities" then 1990
      when "perimeter" then 1996
      when "placement" then 1996
      when "lamplighters" then 1993
      else 1990
      end
      
      # Create infrastructure items for each year it exists
      (start_year..2025).each do |year|
        uid = "infrastructure-#{year}-#{infra['id']}"
        
        # Skip if already exists
        next if SearchableItem.exists?(uid: uid)
        
        item = SearchableItem.create!(
          uid: uid,
          name: "#{infra['name']} (#{year})",
          item_type: "infrastructure",
          year: year,
          description: infra["shortDescription"],
          metadata: {
            infrastructure_id: infra["id"],
            category: infra["category"],
            icon: infra["icon"],
            coordinates: infra["coordinates"],
            locations: infra["locations"],
            history: infra["history"],
            civic_purpose: infra["civicPurpose"],
            legal_context: infra["legalContext"],
            operations: infra["operations"],
            timeline: infra["timeline"],
            did_you_know: infra["didYouKnow"],
            related_links: infra["relatedLinks"]
          }
        )
        
        # Prepare searchable text with all content
        searchable_parts = [
          infra["name"],
          infra["shortDescription"],
          infra["history"],
          infra["civicPurpose"],
          infra["operations"]
        ].compact.join(" ")
        
        item.update!(searchable_text: searchable_parts)
        
        # Generate embedding
        item.generate_embedding!
        
        puts "  ✓ Created for year #{year}"
      end
    end
    
    puts "\n✅ Infrastructure import complete!"
    puts "   Total infrastructure items: #{SearchableItem.where(item_type: 'infrastructure').count}"
  end
  
  desc "Import JSON Archive data for a specific year"
  task :import_json_archive, [:year, :generate_embeddings] => :environment do |t, args|
    year = args[:year]&.to_i
    generate_embeddings = args[:generate_embeddings] != 'false'
    
    unless year && [2015, 2016, 2017, 2018, 2019, 2022, 2023, 2024].include?(year)
      puts "❌ Please provide a valid year with JSON Archive data"
      puts "   Available years: 2015-2019, 2022-2024"
      puts "   Usage: rails burning_man:import_json_archive[2024]"
      puts "   To skip embeddings: rails burning_man:import_json_archive[2024,false]"
      exit 1
    end
    
    puts "📦 Importing JSON Archive data for #{year}..."
    puts "   Embeddings: #{generate_embeddings ? 'enabled' : 'disabled'}"
    
    service = Search::HistoricalDataImportService.new(year, generate_embeddings: generate_embeddings)
    stats = service.import_all
    
    puts "\n✅ Import complete for #{year}!"
    puts "   Camps: #{stats[:camps]}"
    puts "   Art: #{stats[:art]}"
    puts "   Events: #{stats[:events]}"
    
    if generate_embeddings && stats[:items_for_embedding]&.any?
      puts "   Items queued for embeddings: #{stats[:items_for_embedding].count}"
    end
    
    if stats[:errors].any?
      puts "\n⚠️  Errors encountered:"
      stats[:errors].first(10).each { |error| puts "   - #{error}" }
      puts "   ... and #{stats[:errors].count - 10} more" if stats[:errors].count > 10
    end
  end
  
  desc "Import all JSON Archive data (2015-2024) without embeddings"
  task import_all_json_archives: :environment do
    years = [2015, 2016, 2017, 2018, 2019, 2022, 2023, 2024]
    
    puts "🔥 Importing JSON Archive data for all available years..."
    puts "   Years: #{years.join(', ')}"
    puts "   Embeddings: DISABLED (will be generated in batch later)"
    
    total_stats = { camps: 0, art: 0, events: 0, errors: [] }
    
    years.each do |year|
      puts "\n📅 Processing #{year}..."
      
      # Skip if already imported
      existing_count = SearchableItem.where(year: year, item_type: ['camp', 'art', 'event']).count
      if existing_count > 0
        puts "   ⏭️  Skipping #{year} (#{existing_count} items already imported)"
        next
      end
      
      service = Search::HistoricalDataImportService.new(year, generate_embeddings: false)
      stats = service.import_all
      
      total_stats[:camps] += stats[:camps]
      total_stats[:art] += stats[:art]
      total_stats[:events] += stats[:events]
      total_stats[:errors].concat(stats[:errors])
      
      puts "   ✓ #{year}: #{stats[:camps]} camps, #{stats[:art]} art, #{stats[:events]} events"
    end
    
    puts "\n🎉 All JSON Archive imports complete!"
    puts "   Total Camps: #{total_stats[:camps]}"
    puts "   Total Art: #{total_stats[:art]}"
    puts "   Total Events: #{total_stats[:events]}"
    puts "   Total Items: #{total_stats[:camps] + total_stats[:art] + total_stats[:events]}"
    
    if total_stats[:errors].any?
      puts "\n⚠️  Total errors: #{total_stats[:errors].count}"
    end
    
    # Show embedding status
    items_without_embeddings = SearchableItem.where(embedding: nil).count
    puts "\n🔍 Embedding Status:"
    puts "   Items without embeddings: #{items_without_embeddings.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts "   Ready for batch processing: rails burning_man:generate_embeddings_batch"
  end

  desc "Generate embeddings for items without them (immediate processing)"
  task generate_embeddings: :environment do
    items_without_embeddings = SearchableItem.where(embedding: nil)
    count = items_without_embeddings.count
    
    if count == 0
      puts "✅ All items already have embeddings!"
      next
    end
    
    puts "🔍 Found #{count} items without embeddings"
    puts "⚡ Using immediate processing (more expensive but faster)"
    
    batch_service = Search::BatchEmbeddingService.new
    batch_service.generate_embeddings_for_items(items_without_embeddings)
    
    puts "✅ Embeddings generation started for #{count} items"
  end
  
  desc "Generate embeddings using Batch API with webhooks"
  task generate_embeddings_batch: :environment do
    items_without_embeddings = SearchableItem.where(embedding: nil)
    count = items_without_embeddings.count
    
    if count == 0
      puts "✅ All items already have embeddings!"
      next
    end
    
    puts "🔍 Found #{count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} items without embeddings"
    puts "💰 Using Batch API for 50% cost savings"
    puts "🔗 Webhook notifications enabled for completion"
    
    # Check prerequisites
    unless ENV['OPENAI_API_KEY']
      puts "❌ OPENAI_API_KEY not set"
      exit 1
    end
    
    unless ENV['OPENAI_WEBHOOK_SECRET']
      puts "⚠️  OPENAI_WEBHOOK_SECRET not set - webhooks won't work"
      puts "   You can still create the batch, but you'll need to check status manually"
    end
    
    # Estimate cost
    avg_tokens = 70 # Based on our analysis
    total_tokens = count * avg_tokens
    batch_cost = (total_tokens / 1000.0) * 0.00001 # 50% of $0.00002
    
    puts "\n💰 Cost Estimate:"
    puts "   Total tokens: #{total_tokens.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts "   Batch API cost: $#{sprintf('%.4f', batch_cost)}"
    puts "   Processing time: Up to 24 hours"
    
    puts "\n🚀 Creating batch job..."
    batch_service = Search::BatchEmbeddingService.new
    
    begin
      result = batch_service.queue_batch_job(
        items_without_embeddings,
        description: "Complete historical dataset embeddings (#{count} items)"
      )
      
      puts "✅ Batch job created successfully!"
      puts "   OpenAI Batch ID: #{result[:openai_batch_id]}"
      puts "   Local Batch ID: #{result[:local_batch_id]}"
      puts "   Items queued: #{result[:item_count].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
      
      puts "\n📡 Monitoring:"
      puts "   OpenAI Console: https://platform.openai.com/batches/#{result[:openai_batch_id]}"
      puts "   Webhook endpoint: /api/v1/webhooks/openai_batch"
      puts "   Cache key: batch_#{result[:local_batch_id]}"
      
      puts "\n⏰ What happens next:"
      puts "   1. OpenAI processes your batch (up to 24 hours)"
      puts "   2. Webhook automatically updates your database"
      puts "   3. Check progress: rails burning_man:report"
      
    rescue => e
      puts "❌ Failed to create batch job: #{e.message}"
      puts "   Error: #{e.class}"
      exit 1
    end
  end

  desc "Generate historical data report"
  task report: :environment do
    puts "\n📊 Burning Man Historical Database Report"
    puts "=" * 60
    
    # Years with data
    years_with_data = BurningManYear.pluck(:year).sort
    puts "\n📅 Years in Database: #{years_with_data.count}"
    puts "   Range: #{years_with_data.first} - #{years_with_data.last}"
    
    # Items by type
    puts "\n📦 Searchable Items by Type:"
    SearchableItem.group(:item_type).count.each do |type, count|
      puts "   #{type}: #{count}"
    end
    
    # Items by year
    puts "\n📈 Items by Year (top 10):"
    by_year = SearchableItem.group(:year).count.sort_by { |y, c| -c }.first(10)
    by_year.each do |year, count|
      puts "   #{year}: #{count} items"
    end
    
    # Infrastructure coverage
    puts "\n🏗️  Infrastructure Coverage:"
    infra_years = SearchableItem.where(item_type: 'infrastructure')
                                .distinct.pluck(:year).sort
    puts "   Years with infrastructure: #{infra_years.count}"
    puts "   Earliest: #{infra_years.first}"
    puts "   Latest: #{infra_years.last}"
    
    # Theme coverage
    puts "\n🎨 Theme Coverage:"
    themes = BurningManYear.where.not(theme: nil).count
    puts "   Years with themes: #{themes}"
    puts "   First theme: #{BurningManYear.where.not(theme: nil).order(:year).first&.display_name}"
    
    puts "\n✨ Ready for vector search across #{SearchableItem.count} items!"
  end
end