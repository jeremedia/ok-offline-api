#!/usr/bin/env ruby
require_relative 'config/environment'

puts "Checking neighbor gem and database setup..."
puts "=" * 60

# 1. Check pgvector extension
puts "\n1. PostgreSQL extensions:"
extensions = ActiveRecord::Base.connection.execute("SELECT extname, extversion FROM pg_extension")
extensions.each do |ext|
  puts "  - #{ext['extname']} v#{ext['extversion']}"
end

# 2. Check table structure
puts "\n2. Searchable items table structure:"
columns = ActiveRecord::Base.connection.columns('searchable_items')
embedding_col = columns.find { |c| c.name == 'embedding' }
if embedding_col
  puts "  Embedding column:"
  puts "    - Type: #{embedding_col.type}"
  puts "    - SQL Type: #{embedding_col.sql_type}"
  puts "    - Array: #{embedding_col.array?}"
  puts "    - Limit: #{embedding_col.limit}"
end

# 3. Check indexes
puts "\n3. Vector indexes:"
indexes = ActiveRecord::Base.connection.indexes('searchable_items')
indexes.each do |idx|
  if idx.columns.include?('embedding')
    puts "  #{idx.name}:"
    puts "    - Using: #{idx.using}"
    puts "    - Unique: #{idx.unique}"
    puts "    - Comment: #{idx.comment}"
    
    # Get more details
    idx_details = ActiveRecord::Base.connection.execute(<<-SQL
      SELECT 
        am.amname as index_method,
        opcname as opclass
      FROM pg_index ix
      JOIN pg_class i ON i.oid = ix.indexrelid
      JOIN pg_class t ON t.oid = ix.indrelid
      JOIN pg_am am ON am.oid = i.relam
      LEFT JOIN pg_opclass opc ON opc.oid = ANY(ix.indclass)
      WHERE t.relname = 'searchable_items'
        AND i.relname = '#{idx.name}'
      LIMIT 1
    SQL
    ).first
    
    if idx_details
      puts "    - Method: #{idx_details['index_method']}"
      puts "    - Opclass: #{idx_details['opclass']}"
    end
  end
end

# 4. Test different neighbor syntaxes
puts "\n4. Testing neighbor gem syntaxes:"
sample = SearchableItem.where.not(embedding: nil).first
test_embedding = sample.embedding

# Test A: Simple nearest_neighbors
puts "\n  A. Simple nearest_neighbors:"
begin
  results = SearchableItem
    .nearest_neighbors(:embedding, test_embedding, distance: "cosine")
    .limit(3)
    .to_a
  puts "     Success! Found #{results.length} results"
rescue => e
  puts "     Error: #{e.message}"
end

# Test B: With basic where clause
puts "\n  B. With where clause (year = 2024):"
begin
  results = SearchableItem
    .where(year: 2024)
    .nearest_neighbors(:embedding, test_embedding, distance: "cosine")
    .limit(3)
    .to_a
  puts "     Success! Found #{results.length} results"
rescue => e
  puts "     Error: #{e.message}"
end

# Test C: With where clause (year = 2017)
puts "\n  C. With where clause (year = 2017):"
begin
  results = SearchableItem
    .where(year: 2017)
    .nearest_neighbors(:embedding, test_embedding, distance: "cosine")
    .limit(3)
    .to_a
  puts "     Success! Found #{results.length} results"
rescue => e
  puts "     Error: #{e.message}"
end

# 5. Check if it's a data size issue
puts "\n5. Data distribution:"
year_counts = SearchableItem.where.not(embedding: nil).group(:year).count
puts "  Items with embeddings by year:"
year_counts.sort_by { |year, _| year }.each do |year, count|
  puts "    #{year}: #{count.to_s.rjust(6)} items"
end

# 6. Test raw pgvector query
puts "\n6. Testing raw pgvector query:"
begin
  # Use parameter binding to avoid SQL injection
  sql = <<-SQL
    SELECT COUNT(*) as count
    FROM searchable_items
    WHERE year = 2017
      AND embedding IS NOT NULL
      AND embedding <=> $1::vector < 1.0
  SQL
  
  vector_param = "[#{test_embedding.join(',')}]"
  result = ActiveRecord::Base.connection.exec_query(sql, 'SQL', [[nil, vector_param]])
  puts "  2017 items within distance 1.0: #{result.rows.first.first}"
rescue => e
  puts "  Error: #{e.message}"
end

# 7. Check neighbor gem version and configuration
puts "\n7. Neighbor gem info:"
if defined?(Neighbor)
  puts "  Neighbor module loaded: ✓"
  if Neighbor.respond_to?(:version)
    puts "  Version method available: #{Neighbor.version}"
  end
else
  puts "  Neighbor module NOT loaded!"
end

# Check if SearchableItem has neighbor methods
puts "\n8. SearchableItem neighbor methods:"
puts "  has nearest_neighbors method: #{SearchableItem.respond_to?(:nearest_neighbors)}"
puts "  instance has neighbor_distance: #{SearchableItem.new.respond_to?(:neighbor_distance)}"