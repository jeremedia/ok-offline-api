# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

class Neo4jHttpService
  def initialize
    @base_url = 'http://localhost:7474'
    @username = 'neo4j'
    @password = ENV['NEO4J_PASSWORD'] || 'neo4j'
  end

  def execute_query(cypher, parameters = {})
    uri = URI("#{@base_url}/db/neo4j/tx/commit")
    req = Net::HTTP::Post.new(uri)
    req.basic_auth(@username, @password)
    req['Content-Type'] = 'application/json'
    req['Accept'] = 'application/json'
    
    req.body = {
      statements: [{
        statement: cypher,
        parameters: parameters
      }]
    }.to_json
    
    res = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }
    
    if res.code == '200'
      response = JSON.parse(res.body)
      if response['errors'].any?
        raise "Neo4j error: #{response['errors'].first['message']}"
      end
      
      # Extract results
      if response['results'].any? && response['results'].first['data'].any?
        response['results'].first['data'].map { |row| row['row'] }
      else
        []
      end
    else
      raise "HTTP #{res.code}: #{res.body}"
    end
  end

  def import_burning_man_graph
    puts "Starting Burning Man knowledge graph import..."
    
    # Create constraints and indexes
    create_indexes
    
    # Import in batches
    import_items_batch
    import_pool_entities_batch
    create_entity_relationships
    
    puts "Import complete!"
  end

  private

  def create_indexes
    puts "Creating indexes..."
    
    execute_query("CREATE CONSTRAINT IF NOT EXISTS FOR (i:Item) REQUIRE i.uid IS UNIQUE")
    execute_query("CREATE INDEX IF NOT EXISTS FOR (e:Entity) ON (e.name)")
    execute_query("CREATE INDEX IF NOT EXISTS FOR (e:Entity) ON (e.pool)")
    execute_query("CREATE INDEX IF NOT EXISTS FOR (i:Item) ON (i.year)")
  rescue => e
    puts "Index creation warning: #{e.message}"
  end

  def import_items_batch
    puts "Importing items..."
    
    batch_size = 500
    total = SearchableItem.count
    processed = 0
    
    SearchableItem.find_in_batches(batch_size: batch_size) do |items|
      # Build batch data
      items_data = items.map do |item|
        {
          uid: "#{item.item_type}-#{item.year}-#{item.id}",
          name: item.name,
          type: item.item_type,
          year: item.year,
          description: item.description&.truncate(500),
          location: item.location_string
        }
      end
      
      # Create nodes in batch
      items_data.each do |item_data|
        execute_query(
          "MERGE (i:Item {uid: $uid}) SET i.name = $name, i.type = $type, i.year = $year, i.description = $description, i.location = $location",
          item_data
        )
      end
      
      processed += items.size
      puts "  Imported #{processed}/#{total} items..."
    end
  end

  def import_pool_entities_batch
    puts "Importing pool entities..."
    
    pool_types = SearchEntity.where("entity_type LIKE 'pool_%'").distinct.pluck(:entity_type)
    
    pool_types.each do |pool_type|
      pool_name = pool_type.sub('pool_', '')
      puts "  Processing #{pool_name} pool..."
      
      # Get unique entities
      entities = SearchEntity
        .where(entity_type: pool_type)
        .group(:entity_value)
        .count
        
      entities.each do |entity_name, count|
        execute_query(
          "MERGE (e:Entity {name: $name, pool: $pool}) SET e.occurrence_count = $count",
          { name: entity_name, pool: pool_name, count: count }
        )
      end
      
      # Create relationships
      SearchEntity.where(entity_type: pool_type).find_in_batches(batch_size: 500) do |entity_items|
        entity_items.each do |ei|
          item_uid = "#{ei.searchable_item.item_type}-#{ei.searchable_item.year}-#{ei.searchable_item_id}"
          
          execute_query(
            "MATCH (i:Item {uid: $item_uid}), (e:Entity {name: $entity_name, pool: $pool}) MERGE (i)-[:HAS_ENTITY {pool: $pool}]->(e)",
            { item_uid: item_uid, entity_name: ei.entity_value, pool: pool_name }
          )
        end
      end
    end
  end

  def create_entity_relationships
    puts "Creating cross-entity relationships..."
    
    # This would be very slow with HTTP API, so we'll skip for now
    puts "  Skipping APPEARS_WITH relationships for HTTP import (too slow)"
  end

  # Query methods
  def find_related_items(entity_name, pool: nil, limit: 10)
    if pool
      query = "MATCH (e:Entity {name: $entity_name, pool: $pool})<-[:HAS_ENTITY]-(i:Item) RETURN i.name as name, i.type as type, i.year as year, i.description as description ORDER BY i.year DESC LIMIT $limit"
      execute_query(query, { entity_name: entity_name, pool: pool, limit: limit })
    else
      query = "MATCH (e:Entity {name: $entity_name})<-[:HAS_ENTITY]-(i:Item) RETURN i.name as name, i.type as type, i.year as year, i.description as description, e.pool as pool ORDER BY i.year DESC LIMIT $limit"
      execute_query(query, { entity_name: entity_name, limit: limit })
    end
  end

  def stats
    {
      items: execute_query("MATCH (i:Item) RETURN COUNT(i) as count").first&.first || 0,
      entities: execute_query("MATCH (e:Entity) RETURN COUNT(e) as count").first&.first || 0,
      relationships: execute_query("MATCH ()-[r:HAS_ENTITY]->() RETURN COUNT(r) as count").first&.first || 0
    }
  end
end