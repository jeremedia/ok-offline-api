#!/usr/bin/env ruby
require_relative 'config/environment'

puts "Debugging why 2017 returns 0 results..."
puts "=" * 60

# Get a 2017 and 2024 temple item
temple_2017 = SearchableItem.where(year: 2017).where("name ILIKE ?", "%temple%").first
temple_2024 = SearchableItem.where(year: 2024).where("name ILIKE ?", "%temple%").first

puts "\nComparing embeddings:"
puts "2017 Temple: #{temple_2017.name}"
puts "  - Embedding exists: #{!temple_2017.embedding.nil?}"
puts "  - Embedding class: #{temple_2017.embedding.class}"
puts "  - Embedding size: #{temple_2017.embedding.size}"
puts "  - First 5 values: #{temple_2017.embedding.first(5).map { |v| v.round(4) }}"

puts "\n2024 Temple: #{temple_2024.name}"
puts "  - Embedding exists: #{!temple_2024.embedding.nil?}"
puts "  - Embedding class: #{temple_2024.embedding.class}"
puts "  - Embedding size: #{temple_2024.embedding.size}"
puts "  - First 5 values: #{temple_2024.embedding.first(5).map { |v| v.round(4) }}"

# Test direct nearest_neighbors on specific item
puts "\n\nDirect nearest_neighbors test:"
test_embedding = temple_2024.embedding

# Test 1: Can we find the exact same item?
puts "\n1. Finding exact match (should find itself):"
exact_match = SearchableItem
  .where(id: temple_2024.id)
  .nearest_neighbors(:embedding, test_embedding, distance: "cosine")
  .first

if exact_match
  puts "   Found: #{exact_match.name}"
else
  puts "   NOT FOUND!"
end

# Test 2: Search in 2024 excluding self
puts "\n2. Search in 2024 (excluding self):"
results_2024 = SearchableItem
  .where(year: 2024)
  .where.not(id: temple_2024.id)
  .nearest_neighbors(:embedding, test_embedding, distance: "cosine")
  .limit(3)
  .to_a

puts "   Found #{results_2024.length} results"

# Test 3: Search in 2017 with temple_2024's embedding
puts "\n3. Search in 2017 using 2024 temple embedding:"
results_2017 = SearchableItem
  .where(year: 2017)
  .nearest_neighbors(:embedding, test_embedding, distance: "cosine")
  .limit(3)
  .to_a

puts "   Found #{results_2017.length} results"

# Test 4: Search all years
puts "\n4. Search ALL years with no filter:"
results_all = SearchableItem
  .nearest_neighbors(:embedding, test_embedding, distance: "cosine")
  .limit(10)
  .to_a

puts "   Found #{results_all.length} results:"
results_all.each do |item|
  puts "   - #{item.name} (#{item.year})"
end

# Test 5: Manual distance calculation
puts "\n5. Manual distance calculation for 2017 temples:"
temple_items_2017 = SearchableItem.where(year: 2017).where("name ILIKE ?", "%temple%").limit(3)
temple_items_2017.each do |item|
  # Cosine distance = 1 - cosine similarity
  dot_product = test_embedding.zip(item.embedding).sum { |a, b| a * b }
  distance = 1 - dot_product  # Since embeddings are normalized
  puts "   - #{item.name}: distance = #{distance.round(4)}"
end

# Test 6: Check if it's a Rails scope issue
puts "\n6. Using unscoped:"
unscoped_2017 = SearchableItem.unscoped
  .where(year: 2017)
  .where.not(embedding: nil)
  .nearest_neighbors(:embedding, test_embedding, distance: "cosine")
  .limit(3)
  .to_a

puts "   Found #{unscoped_2017.length} results"

# Test 7: Direct SQL to bypass neighbor gem
puts "\n7. Direct SQL query:"
sql = <<-SQL
  SELECT id, name, year
  FROM searchable_items
  WHERE year = 2017
    AND embedding IS NOT NULL
  ORDER BY embedding <=> $1::vector
  LIMIT 3
SQL

vector_string = "[#{test_embedding.join(',')}]"
begin
  results = ActiveRecord::Base.connection.exec_query(sql, 'SQL', [[nil, vector_string]])
  puts "   Found #{results.rows.length} results:"
  results.rows.each do |row|
    puts "   - #{row[1]} (ID: #{row[0]})"
  end
rescue => e
  puts "   Error: #{e.message}"
end