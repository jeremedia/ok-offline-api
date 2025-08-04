#!/usr/bin/env ruby
require_relative 'config/environment'

puts "Diagnosing vector search issue..."
puts "=" * 60

# Check exact index definition
puts "\nChecking index definition:"
index_info = ActiveRecord::Base.connection.execute(<<-SQL
  SELECT 
    i.relname as index_name,
    am.amname as index_method,
    opcname as opclass,
    pg_get_indexdef(indexrelid) as definition
  FROM pg_index ix
  JOIN pg_class i ON i.oid = ix.indexrelid
  JOIN pg_class t ON t.oid = ix.indrelid
  JOIN pg_am am ON am.oid = i.relam
  LEFT JOIN pg_opclass opc ON opc.oid = ANY(ix.indclass)
  WHERE t.relname = 'searchable_items'
    AND i.relname LIKE '%embedding%'
SQL
)

index_info.each do |row|
  puts "Index: #{row['index_name']}"
  puts "Method: #{row['index_method']}"
  puts "Opclass: #{row['opclass']}"
  puts "Definition: #{row['definition']}"
  puts ""
end

# Test with proper vector format
puts "\nTesting with proper vector format:"
test_embedding = Array.new(1536) { rand(-0.1..0.1) }
vector_string = "[#{test_embedding.join(',')}]"

# First, let's check a sample embedding format
sample = SearchableItem.where(year: 2017).where.not(embedding: nil).first
if sample
  puts "Sample embedding class: #{sample.embedding.class}"
  puts "Sample embedding length: #{sample.embedding.length}"
  puts "First 5 values: #{sample.embedding.first(5)}"
end

# Test different query approaches
puts "\nTest 1: Using raw SQL with proper vector cast:"
begin
  sql = <<-SQL
    SELECT id, name, year,
           (embedding <=> '#{vector_string}'::vector) as distance
    FROM searchable_items
    WHERE embedding IS NOT NULL
      AND year = 2017
    ORDER BY embedding <=> '#{vector_string}'::vector
    LIMIT 5
  SQL
  
  results = ActiveRecord::Base.connection.execute(sql)
  puts "Found #{results.count} results"
  results.first(3).each do |row|
    puts "  - #{row['name']} (#{row['year']}) - distance: #{row['distance'].to_f.round(4)}"
  end
rescue => e
  puts "Error: #{e.message}"
end

# Test 2: Check if neighbor gem is passing the right format
puts "\nTest 2: Debug neighbor gem query:"
begin
  # Enable query logging
  ActiveRecord::Base.logger = Logger.new(STDOUT)
  
  results = SearchableItem
    .where(year: 2017)
    .where.not(embedding: nil)
    .nearest_neighbors(:embedding, test_embedding, distance: "cosine")
    .limit(5)
    .to_sql
  
  puts "Generated SQL:"
  puts results
  
  # Turn off query logging
  ActiveRecord::Base.logger = Rails.logger
rescue => e
  puts "Error: #{e.message}"
end

# Test 3: Try without year filter
puts "\nTest 3: Search without year filter:"
begin
  results = SearchableItem
    .where.not(embedding: nil)
    .nearest_neighbors(:embedding, test_embedding, distance: "cosine")
    .limit(5)
    .pluck(:name, :year)
  
  puts "Found #{results.length} results:"
  results.each do |name, year|
    puts "  - #{name} (#{year})"
  end
rescue => e
  puts "Error: #{e.message}"
end

# Test 4: Direct neighbor calculation
puts "\nTest 4: Manual distance calculation for 2017 items:"
items_2017 = SearchableItem.where(year: 2017).where.not(embedding: nil).limit(5)
items_2017.each do |item|
  # Calculate cosine distance manually
  dot_product = test_embedding.zip(item.embedding).sum { |a, b| a * b }
  mag1 = Math.sqrt(test_embedding.sum { |x| x**2 })
  mag2 = Math.sqrt(item.embedding.sum { |x| x**2 })
  cosine_similarity = dot_product / (mag1 * mag2)
  cosine_distance = 1 - cosine_similarity
  
  puts "  - #{item.name}: distance = #{cosine_distance.round(4)}"
end