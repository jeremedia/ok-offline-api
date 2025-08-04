#!/usr/bin/env ruby
require_relative 'config/environment'

puts "Detailed neighbor gem testing..."
puts "=" * 60

# Get a real embedding from the database
sample = SearchableItem.where.not(embedding: nil).first
test_embedding = sample.embedding

puts "Using embedding from: #{sample.name} (#{sample.year})"
puts "Embedding class: #{test_embedding.class}"
puts "Embedding size: #{test_embedding.size}"

# Test 1: Direct neighbor call on 2024 (works)
puts "\n1. Testing on 2024 data (works):"
results = SearchableItem
  .where(year: 2024)
  .nearest_neighbors(:embedding, test_embedding, distance: "cosine")
  .limit(3)

puts "SQL generated:"
puts results.to_sql
puts "\nResults:"
results.each { |r| puts "  - #{r.name}" }

# Test 2: Direct neighbor call on 2017 (fails)
puts "\n2. Testing on 2017 data (fails):"
results = SearchableItem
  .where(year: 2017)
  .nearest_neighbors(:embedding, test_embedding, distance: "cosine")
  .limit(3)

puts "SQL generated:"
puts results.to_sql
puts "\nResults:"
begin
  results.each { |r| puts "  - #{r.name}" }
rescue => e
  puts "Error: #{e.message}"
end

# Test 3: Check scopes interaction
puts "\n3. Testing scope order:"

# Try nearest_neighbors first, then where
results1 = SearchableItem
  .nearest_neighbors(:embedding, test_embedding, distance: "cosine")
  .where(year: 2017)
  .limit(3)

puts "nearest_neighbors -> where SQL:"
puts results1.to_sql

# Try where first, then nearest_neighbors
results2 = SearchableItem
  .where(year: 2017)
  .nearest_neighbors(:embedding, test_embedding, distance: "cosine")
  .limit(3)

puts "\nwhere -> nearest_neighbors SQL:"
puts results2.to_sql

# Test 4: Check if it's a scope merging issue
puts "\n4. Testing with fresh scope:"
fresh_scope = SearchableItem.where(year: 2017).where.not(embedding: nil)
puts "Items in 2017 with embeddings: #{fresh_scope.count}"

# Use unscoped to bypass any default scopes
unscoped_results = SearchableItem.unscoped
  .where(year: 2017)
  .where.not(embedding: nil)
  .nearest_neighbors(:embedding, test_embedding, distance: "cosine")
  .limit(3)

puts "\nUnscoped SQL:"
puts unscoped_results.to_sql

begin
  puts "\nUnscoped results:"
  unscoped_results.each { |r| puts "  - #{r.name}" }
rescue => e
  puts "Error: #{e.message}"
end