# frozen_string_literal: true

require 'neo4j_ruby_driver'

class Neo4jGraphService
  def initialize
    # Use the connection from the initializer
  end

  def close
    # Connection is managed by Neo4jConnection
  end

  def with_session(&block)
    Neo4jConnection.session(database: 'neo4j') do |session|
      yield session
    end
  end

  # Import all pool entities and searchable items
  def import_burning_man_graph
    puts "Starting Burning Man knowledge graph import..."
    
    with_session do |session|
      # Clear existing data (optional)
      # session.run("MATCH (n) DETACH DELETE n")
      
      # Create constraints and indexes
      create_indexes(session)
      
      # Import searchable items as nodes
      import_items(session)
      
      # Import pool entities and create relationships
      import_pool_entities(session)
      
      # Create cross-pool relationships
      create_entity_relationships(session)
    end
    
    puts "Import complete!"
  end

  private

  def create_indexes(session)
    puts "Creating indexes..."
    
    # Unique constraint on BM items
    session.run("CREATE CONSTRAINT IF NOT EXISTS FOR (i:BM_Item) REQUIRE i.uid IS UNIQUE")
    
    # Indexes for BM entities
    session.run("CREATE INDEX IF NOT EXISTS FOR (e:BM_Entity) ON (e.name)")
    session.run("CREATE INDEX IF NOT EXISTS FOR (e:BM_Entity) ON (e.pool)")
    
    # Index for years
    session.run("CREATE INDEX IF NOT EXISTS FOR (i:BM_Item) ON (i.year)")
    
    # Composite indexes
    session.run("CREATE INDEX IF NOT EXISTS FOR (e:BM_Entity) ON (e.pool, e.name)")
  end

  def import_items(session)
    puts "Importing items..."
    
    batch_size = 1000
    total = SearchableItem.count
    processed = 0
    
    SearchableItem.find_in_batches(batch_size: batch_size) do |items|
      # Build Cypher query for batch insert
      query = <<~CYPHER
        UNWIND $items AS item
        MERGE (i:BM_Item {uid: item.uid})
        SET i.name = item.name,
            i.type = item.item_type,
            i.year = item.year,
            i.description = item.description,
            i.location = item.location_string
      CYPHER
      
      items_data = items.map do |item|
        {
          uid: "#{item.item_type}-#{item.year}-#{item.id}",
          name: item.name,
          item_type: item.item_type,
          year: item.year,
          description: item.description&.truncate(500),
          location_string: item.location_string
        }
      end
      
      session.run(query, items: items_data)
      
      processed += items.size
      puts "  Imported #{processed}/#{total} items..."
    end
  end

  def import_pool_entities(session)
    puts "Importing pool entities..."
    
    # Get all pool types
    pool_types = SearchEntity.where("entity_type LIKE 'pool_%'").distinct.pluck(:entity_type)
    
    pool_types.each do |pool_type|
      pool_name = pool_type.sub('pool_', '')
      puts "  Importing #{pool_name} pool entities..."
      
      # Get unique entities for this pool
      entities = SearchEntity
        .where(entity_type: pool_type)
        .group(:entity_value)
        .count
      
      # Batch import entities
      entity_batch = entities.map do |entity_name, count|
        {
          name: entity_name,
          pool: pool_name,
          occurrence_count: count
        }
      end
      
      query = <<~CYPHER
        UNWIND $entities AS entity
        MERGE (e:BM_Entity {name: entity.name, pool: entity.pool})
        SET e.occurrence_count = entity.occurrence_count
      CYPHER
      
      session.run(query, entities: entity_batch)
      
      # Create relationships between items and entities
      puts "  Creating relationships for #{pool_name} pool..."
      
      SearchEntity.where(entity_type: pool_type).find_in_batches(batch_size: 1000) do |entity_items|
        relationships = entity_items.map do |ei|
          {
            item_uid: "#{ei.searchable_item.item_type}-#{ei.searchable_item.year}-#{ei.searchable_item_id}",
            entity_name: ei.entity_value,
            pool: pool_name,
            confidence: ei.confidence || 1.0
          }
        end
        
        rel_query = <<~CYPHER
          UNWIND $rels AS rel
          MATCH (i:BM_Item {uid: rel.item_uid})
          MATCH (e:BM_Entity {name: rel.entity_name, pool: rel.pool})
          MERGE (i)-[r:BM_HAS_ENTITY {pool: rel.pool}]->(e)
          SET r.confidence = rel.confidence
        CYPHER
        
        session.run(rel_query, rels: relationships)
      end
    end
  end

  def create_entity_relationships(session)
    puts "Creating cross-entity relationships..."
    
    # Create relationships between entities that appear together
    query = <<~CYPHER
      MATCH (e1:BM_Entity)
      WITH e1
      MATCH (e1)<-[:BM_HAS_ENTITY]-(i:BM_Item)-[:BM_HAS_ENTITY]->(e2:BM_Entity)
      WHERE e1.name < e2.name
      WITH e1, e2, COUNT(DISTINCT i) as cooccurrence_count
      WHERE cooccurrence_count > 2
      MERGE (e1)-[r:BM_APPEARS_WITH]->(e2)
      SET r.count = cooccurrence_count
      RETURN COUNT(r) as relationships_created
    CYPHER
    
    result = session.run(query)
    count = result.single[:relationships_created]
    puts "  Created #{count} entity relationships"
  end

  # Query methods
  def find_related_items(entity_name, pool: nil, limit: 10)
    with_session do |session|
      if pool
        query = <<~CYPHER
          MATCH (e:BM_Entity {name: $entity_name, pool: $pool})
          MATCH (e)<-[:BM_HAS_ENTITY]-(i:BM_Item)
          RETURN i.name as name, i.type as type, i.year as year, i.description as description
          ORDER BY i.year DESC
          LIMIT $limit
        CYPHER
        
        session.run(query, entity_name: entity_name, pool: pool, limit: limit).to_a
      else
        query = <<~CYPHER
          MATCH (e:BM_Entity {name: $entity_name})
          MATCH (e)<-[:BM_HAS_ENTITY]-(i:BM_Item)
          RETURN i.name as name, i.type as type, i.year as year, i.description as description, e.pool as pool
          ORDER BY i.year DESC
          LIMIT $limit
        CYPHER
        
        session.run(query, entity_name: entity_name, limit: limit).to_a
      end
    end
  end

  def find_entity_connections(entity_name, max_depth: 2)
    with_session do |session|
      query = <<~CYPHER
        MATCH path = (e1:BM_Entity {name: $entity_name})-[:BM_APPEARS_WITH*1..#{max_depth}]-(e2:BM_Entity)
        WHERE e1 <> e2
        RETURN DISTINCT e2.name as related_entity, e2.pool as pool, LENGTH(path) as distance
        ORDER BY distance, e2.name
        LIMIT 20
      CYPHER
      
      session.run(query, entity_name: entity_name).to_a
    end
  end

  def find_pool_bridges(pool1, pool2)
    with_session do |session|
      query = <<~CYPHER
        MATCH (i:BM_Item)-[:BM_HAS_ENTITY]->(e1:BM_Entity {pool: $pool1})
        MATCH (i)-[:BM_HAS_ENTITY]->(e2:BM_Entity {pool: $pool2})
        WITH i, COLLECT(DISTINCT e1.name) as pool1_entities, COLLECT(DISTINCT e2.name) as pool2_entities
        RETURN i.name as name, i.type as type, i.year as year, 
               pool1_entities[0..5] as pool1_entities,
               pool2_entities[0..5] as pool2_entities
        LIMIT 10
      CYPHER
      
      session.run(query, pool1: pool1, pool2: pool2).to_a
    end
  end
end