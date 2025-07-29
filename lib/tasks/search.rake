namespace :search do
  desc "Import data for vector search"
  task :import, [:year] => :environment do |t, args|
    year = args[:year] || 2025
    
    puts "Starting data import for year #{year}..."
    
    # Create import service
    import_service = Search::DataImportService.new
    
    # Import all data types
    import_service.import_year_data(year)
    
    puts "Data import completed!"
    
    # Show statistics
    total = SearchableItem.by_year(year).count
    with_embeddings = SearchableItem.by_year(year).with_embedding.count
    
    puts "\nStatistics:"
    puts "Total items: #{total}"
    puts "Items with embeddings: #{with_embeddings}"
    puts "Completion: #{(with_embeddings.to_f / total * 100).round(2)}%" if total > 0
    
    # Show breakdown by type
    puts "\nBy type:"
    SearchableItem.by_year(year).group(:item_type).count.each do |type, count|
      with_emb = SearchableItem.by_year(year).by_type(type).with_embedding.count
      puts "  #{type}: #{with_emb}/#{count} (#{(with_emb.to_f / count * 100).round(2)}%)"
    end
  end
  
  desc "Generate missing embeddings"
  task :generate_embeddings => :environment do
    items_without_embeddings = SearchableItem.where(embedding: nil)
    total = items_without_embeddings.count
    
    puts "Found #{total} items without embeddings"
    
    if total > 0
      embedding_service = Search::EmbeddingService.new
      
      items_without_embeddings.find_each.with_index do |item, index|
        print "\rGenerating embedding #{index + 1}/#{total}..."
        
        item.generate_embedding!(embedding_service)
        
        # Rate limiting - OpenAI has limits
        sleep 0.1 if (index + 1) % 10 == 0
      end
      
      puts "\nEmbedding generation completed!"
    end
  end
  
  desc "Clear all search data"
  task :clear => :environment do
    puts "Clearing all search data..."
    
    SearchQuery.destroy_all
    SearchEntity.destroy_all
    SearchableItem.destroy_all
    
    puts "Search data cleared!"
  end
  
  desc "Show search statistics"
  task :stats => :environment do
    puts "Search Statistics"
    puts "=================="
    
    puts "\nItems:"
    puts "  Total: #{SearchableItem.count}"
    puts "  With embeddings: #{SearchableItem.with_embedding.count}"
    
    puts "\nBy type:"
    SearchableItem.group(:item_type).count.each do |type, count|
      puts "  #{type}: #{count}"
    end
    
    puts "\nEntities:"
    SearchEntity.group(:entity_type).count.each do |type, count|
      puts "  #{type}: #{count}"
    end
    
    puts "\nSearch queries:"
    puts "  Total: #{SearchQuery.count}"
    puts "  Successful: #{SearchQuery.successful.count}"
    puts "  Average execution time: #{SearchQuery.average_execution_time&.round(2)}s"
    
    puts "\nPopular queries:"
    SearchQuery.popular_queries(limit: 5).each do |query, count|
      puts "  '#{query}': #{count} times"
    end
  end
end