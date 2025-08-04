#!/usr/bin/env ruby
require_relative 'config/environment'

puts "Testing neighbor gem with different approaches..."
puts "=" * 60

# Generate test embedding
embedding_service = Search::EmbeddingService.new
test_embedding = embedding_service.generate_embedding("temple")

# Test 1: Basic neighbor search without WHERE
puts "\nTest 1: Basic nearest_neighbors (no WHERE clause):"
begin
  results = SearchableItem
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

# Test 2: WHERE clause AFTER nearest_neighbors
puts "\nTest 2: WHERE clause AFTER nearest_neighbors:"
begin
  results = SearchableItem
    .nearest_neighbors(:embedding, test_embedding, distance: "cosine")
    .where(year: 2017)
    .limit(5)
    .pluck(:name, :year)
  
  puts "Found #{results.length} results:"
  results.each do |name, year|
    puts "  - #{name} (#{year})"
  end
rescue => e
  puts "Error: #{e.message}"
end

# Test 3: Subquery approach
puts "\nTest 3: Using subquery for year filtering:"
begin
  year_2017_ids = SearchableItem.where(year: 2017).pluck(:id)
  results = SearchableItem
    .where(id: year_2017_ids)
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

# Test 4: Manual search implementation
puts "\nTest 4: Manual vector search for 2017:"
begin
  # First check if 2017 has any temple items
  temple_count = SearchableItem.where(year: 2017).where("name ILIKE ?", "%temple%").count
  puts "2017 has #{temple_count} items with 'temple' in name"
  
  # Now do vector search
  vector_string = "[#{test_embedding.join(',')}]"
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
  puts "Found #{results.count} results:"
  results.each do |row|
    puts "  - #{row['name']} (#{row['year']}) - distance: #{row['distance'].to_f.round(4)}"
  end
rescue => e
  puts "Error: #{e.message}"
end

# Test 5: Check neighbor gem version
puts "\nTest 5: Neighbor gem info:"
neighbor_spec = Gem.loaded_specs['neighbor']
if neighbor_spec
  puts "Neighbor version: #{neighbor_spec.version}"
else
  puts "Neighbor gem not found in loaded specs"
end

# Test 6: Custom search method
puts "\nTest 6: Creating custom search method:"
class SearchableItem
  def self.vector_search_by_year(query_embedding, year, limit: 10)
    vector_string = "[#{query_embedding.join(',')}]"
    sql = <<-SQL
      SELECT *,
             (embedding <=> ?::vector) as distance
      FROM searchable_items
      WHERE embedding IS NOT NULL
        AND year = ?
      ORDER BY embedding <=> ?::vector
      LIMIT ?
    SQL
    
    find_by_sql([sql, vector_string, year, vector_string, limit])
  end
end

results = SearchableItem.vector_search_by_year(test_embedding, 2017, limit: 5)
puts "Found #{results.length} results:"
results.each do |item|
  puts "  - #{item.name} (#{item.year})"
end