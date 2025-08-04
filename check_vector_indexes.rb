#!/usr/bin/env ruby
require_relative 'config/environment'

puts "Checking vector indexes and configuration..."
puts "=" * 60

# Check current indexes on searchable_items
puts "\nCurrent indexes on searchable_items:"
indexes = ActiveRecord::Base.connection.indexes('searchable_items')
indexes.each do |index|
  if index.columns.include?('embedding')
    puts "  Name: #{index.name}"
    puts "  Columns: #{index.columns.join(', ')}"
    puts "  Type: #{index.using || 'btree'}"
    puts "  Unique: #{index.unique}"
    puts "  Comment: #{index.comment}" if index.comment
    puts ""
  end
end

# Check pgvector extension version
begin
  result = ActiveRecord::Base.connection.execute("SELECT extversion FROM pg_extension WHERE extname = 'vector'")
  version = result.first['extversion']
  puts "pgvector version: #{version}"
rescue => e
  puts "Could not check pgvector version: #{e.message}"
end

# Check current ef_search setting
begin
  result = ActiveRecord::Base.connection.execute("SHOW hnsw.ef_search")
  ef_search = result.first['hnsw.ef_search']
  puts "Current hnsw.ef_search: #{ef_search}"
rescue => e
  puts "hnsw.ef_search not available (normal if no HNSW index exists)"
end

# Test a simple vector search
puts "\nTesting vector search..."
embedding_service = Search::EmbeddingService.new
test_embedding = embedding_service.generate_embedding("temple")

if test_embedding
  # Test with raw SQL
  puts "\nTesting raw SQL vector search:"
  sql = <<-SQL
    SELECT id, name, year,
           embedding <=> $1::vector as distance
    FROM searchable_items
    WHERE embedding IS NOT NULL
      AND year = 2017
    ORDER BY embedding <=> $1::vector
    LIMIT 5
  SQL
  
  begin
    results = ActiveRecord::Base.connection.exec_query(
      sql, 
      'SQL', 
      [[nil, test_embedding.to_s.gsub(' ', '')]]
    )
    puts "Found #{results.rows.length} results"
    results.rows.each do |row|
      puts "  - #{row[1]} (#{row[2]}) - distance: #{row[3].round(4)}"
    end
  rescue => e
    puts "SQL Error: #{e.message}"
  end
  
  # Test with neighbor gem
  puts "\nTesting neighbor gem:"
  begin
    results = SearchableItem
      .where(year: 2017)
      .nearest_neighbors(:embedding, test_embedding, distance: "cosine")
      .limit(5)
      .select(:id, :name, :year)
      .to_a
    
    puts "Found #{results.length} results"
    results.each do |item|
      puts "  - #{item.name} (#{item.year})"
    end
  rescue => e
    puts "Neighbor Error: #{e.message}"
    puts e.backtrace.first(3)
  end
end