#!/usr/bin/env ruby

puts "Adding OKNOTOK entity to Neo4j manually..."

service = Neo4jGraphService.new
service.with_session do |session|
  # Create OKNOTOK entity
  session.run(<<~CYPHER, name: "OKNOTOK", pool: "manifest", count: 1)
    MERGE (e:BM_Entity {name: $name})
    SET e.pool = $pool, e.occurrence_count = $count
    RETURN e
  CYPHER
  
  puts "OKNOTOK entity created/updated in Neo4j"
  
  # Verify it exists
  result = session.run(<<~CYPHER, name: "OKNOTOK").to_a.first
    MATCH (e:BM_Entity {name: $name})
    RETURN e.name as name, e.pool as pool, e.occurrence_count as count
  CYPHER
  
  if result
    puts "✅ Verified: OKNOTOK exists in Neo4j"
    puts "   Name: #{result[:name]}"
    puts "   Pool: #{result[:pool]}"
    puts "   Count: #{result[:count]}"
  else
    puts "❌ OKNOTOK not found in Neo4j"
  end
end