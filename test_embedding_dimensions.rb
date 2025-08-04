#!/usr/bin/env ruby
require_relative 'config/environment'

puts "Checking embedding dimensions by year..."
puts "=" * 60

# Check embedding dimensions for each year
years = SearchableItem.distinct.pluck(:year).sort

results = []

years.each do |year|
  items_with_embeddings = SearchableItem.where(year: year).where.not(embedding: nil)
  total_items = SearchableItem.where(year: year).count
  
  if items_with_embeddings.any?
    sample_item = items_with_embeddings.first
    dimensions = sample_item.embedding.length
    
    # Check a few more items to see if dimensions are consistent
    dimension_counts = items_with_embeddings.limit(5).map { |i| i.embedding.length }.uniq
    
    results << {
      year: year,
      total_items: total_items,
      items_with_embeddings: items_with_embeddings.count,
      dimensions: dimensions,
      dimension_variations: dimension_counts
    }
  else
    results << {
      year: year,
      total_items: total_items,
      items_with_embeddings: 0,
      dimensions: nil,
      dimension_variations: []
    }
  end
end

# Display results
puts "Year | Total Items | With Embeddings | Dimensions | Variations"
puts "-" * 70

results.each do |r|
  dims = r[:dimensions] || "N/A"
  vars = r[:dimension_variations].join(", ")
  puts "#{r[:year]} | #{r[:total_items].to_s.rjust(11)} | #{r[:items_with_embeddings].to_s.rjust(15)} | #{dims.to_s.rjust(10)} | #{vars}"
end

# Check specifically for 2017
puts "\n\nDetailed check for 2017:"
problem_years = [2015, 2016, 2017, 2018, 2019]

problem_years.each do |year|
  puts "\n#{year}:"
  sample_items = SearchableItem.where(year: year).where.not(embedding: nil).limit(3)
  
  sample_items.each do |item|
    puts "  - #{item.name}"
    puts "    Embedding dimensions: #{item.embedding.length}"
    puts "    First 5 values: #{item.embedding.first(5).map { |v| v.round(4) }}"
    puts "    Last 5 values: #{item.embedding.last(5).map { |v| v.round(4) }}"
  end
end

# Test direct SQL query for 2017
puts "\n\nTesting direct pgvector query for 2017:"
query = <<-SQL
  SELECT id, name, 
    embedding <=> '[0.1, 0.2, 0.3]'::vector AS distance
  FROM searchable_items
  WHERE year = 2017 
    AND embedding IS NOT NULL
  LIMIT 5
SQL

begin
  results = ActiveRecord::Base.connection.execute(query)
  puts "Direct SQL results: #{results.count}"
rescue => e
  puts "SQL Error: #{e.message}"
end