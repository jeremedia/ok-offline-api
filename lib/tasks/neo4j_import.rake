namespace :neo4j do
  desc "Create burning_man database if it doesn't exist"
  task create_db: :environment do
    puts "Creating burning_man database..."
    
    Neo4jConnection.session(database: 'system') do |session|
      begin
        # Check if database exists
        result = session.run("SHOW DATABASES WHERE name = 'burning_man'")
        if result.to_a.empty?
          # Create the database
          session.run("CREATE DATABASE burning_man IF NOT EXISTS")
          puts "✓ Created burning_man database"
          
          # Wait for database to come online
          sleep 2
        else
          puts "✓ Database burning_man already exists"
        end
      rescue => e
        puts "Error creating database: #{e.message}"
        puts "Note: Database creation requires Neo4j Enterprise Edition or Neo4j Community 5.x+"
      end
    end
  end
  desc "Import Burning Man data into Neo4j knowledge graph"
  task import: :environment do
    puts "Starting Neo4j import..."
    
    service = Neo4jGraphService.new
    begin
      service.import_burning_man_graph
    ensure
      service.close
    end
  end
  
  desc "Test Neo4j queries"
  task test: :environment do
    service = Neo4jGraphService.new
    
    begin
      puts "\n=== Testing Neo4j Queries ==="
      
      # Test 1: Find items related to "fire"
      puts "\n1. Items related to 'fire' entity:"
      results = service.find_related_items("fire", limit: 5)
      results.each do |r|
        puts "  - #{r[:name]} (#{r[:type]}, #{r[:year]})"
      end
      
      # Test 2: Find entity connections
      puts "\n2. Entities connected to 'fire':"
      connections = service.find_entity_connections("fire", max_depth: 2)
      connections.each do |c|
        puts "  - #{c[:related_entity]} (#{c[:pool]}) - distance: #{c[:distance]}"
      end
      
      # Test 3: Find bridges between pools
      puts "\n3. Items bridging 'manifest' and 'experience' pools:"
      bridges = service.find_pool_bridges("manifest", "experience")
      bridges.each do |b|
        puts "  - #{b[:name]} (#{b[:year]})"
        puts "    Manifest: #{b[:pool1_entities].join(', ')}"
        puts "    Experience: #{b[:pool2_entities].join(', ')}"
      end
      
    ensure
      service.close
    end
  end
  
  desc "Get Neo4j stats"
  task stats: :environment do
    puts "Checking Neo4j connection..."
    
    # First verify connectivity
    if Neo4jConnection.verify_connectivity
      puts "✓ Connected to Neo4j successfully!"
    else
      puts "✗ Failed to connect to Neo4j. Please ensure Neo4j is running."
      puts "  URL: #{NEO4J_CONFIG[:url]}"
      puts "  Username: #{NEO4J_CONFIG[:username]}"
      exit 1
    end
    
    service = Neo4jGraphService.new
    
    begin
      service.with_session do |session|
        puts "\nGathering statistics..."
        
        # Count BM nodes
        item_result = session.run("MATCH (i:BM_Item) RETURN COUNT(i) as count").single
        item_count = item_result ? item_result[:count] : 0
        
        entity_result = session.run("MATCH (e:BM_Entity) RETURN COUNT(e) as count").single
        entity_count = entity_result ? entity_result[:count] : 0
        
        # Count BM relationships
        has_entity_result = session.run("MATCH ()-[r:BM_HAS_ENTITY]->() RETURN COUNT(r) as count").single
        has_entity_count = has_entity_result ? has_entity_result[:count] : 0
        
        appears_with_result = session.run("MATCH ()-[r:BM_APPEARS_WITH]->() RETURN COUNT(r) as count").single
        appears_with_count = appears_with_result ? appears_with_result[:count] : 0
        
        puts "\n=== Neo4j Graph Statistics ==="
        puts "Nodes:"
        puts "  Items: #{item_count}"
        puts "  Entities: #{entity_count}"
        puts "  Total: #{item_count + entity_count}"
        puts "\nRelationships:"
        puts "  BM_HAS_ENTITY: #{has_entity_count}"
        puts "  BM_APPEARS_WITH: #{appears_with_count}"
        puts "  Total: #{has_entity_count + appears_with_count}"
        
        # Pool stats
        if entity_count > 0
          puts "\nEntities by pool:"
          pool_stats = session.run(<<~CYPHER
            MATCH (e:BM_Entity)
            RETURN e.pool as pool, COUNT(e) as count
            ORDER BY count DESC
          CYPHER
          ).to_a
          
          pool_stats.each do |stat|
            puts "  #{stat[:pool]}: #{stat[:count]}"
          end
        else
          puts "\nNo entities in graph yet. Run 'rails neo4j:import' to import data."
        end
      end
    rescue => e
      puts "\nError accessing Neo4j: #{e.message}"
      puts "Error class: #{e.class}"
      puts "Backtrace:"
      puts e.backtrace[0..5].join("\n")
    ensure
      service.close
    end
  end
end