#!/usr/bin/env ruby
require_relative 'config/environment'

puts "Debugging 2017 embeddings issue..."
puts "=" * 60

# Check 2017 temple items
temple_2017 = SearchableItem.where(year: 2017).where("name ILIKE ?", "%temple%").first(3)
puts "Sample 2017 temple items:"
temple_2017.each do |item|
  puts "\n#{item.name}:"
  puts "  ID: #{item.id}"
  puts "  Embedding exists: #{!item.embedding.nil?}"
  puts "  Embedding size: #{item.embedding&.size}"
  
  if item.embedding
    # Check if embedding is valid
    is_all_zeros = item.embedding.all? { |v| v == 0 }
    puts "  All zeros: #{is_all_zeros}"
    
    # Check embedding magnitude
    magnitude = Math.sqrt(item.embedding.sum { |v| v**2 })
    puts "  Magnitude: #{magnitude.round(4)}"
    
    # Test direct distance calculation
    test_embedding = Array.new(1536) { 0.1 } # Simple test vector
    begin
      sql = "SELECT embedding <=> $1::vector as distance FROM searchable_items WHERE id = $2"
      result = ActiveRecord::Base.connection.exec_query(sql, 'SQL', [[nil, "[#{test_embedding.join(',')}]"], [nil, item.id]])
      puts "  Direct SQL distance: #{result.rows.first&.first}"
    rescue => e
      puts "  Direct SQL error: #{e.message}"
    end
  end
end

# Check if it's a data type issue
puts "\n\nChecking data types:"
sql = <<-SQL
  SELECT 
    column_name,
    data_type,
    udt_name
  FROM information_schema.columns
  WHERE table_name = 'searchable_items'
    AND column_name = 'embedding'
SQL

result = ActiveRecord::Base.connection.execute(sql)
result.each do |row|
  puts "Column: #{row['column_name']}, Type: #{row['data_type']}, UDT: #{row['udt_name']}"
end

# Test with a known working year (2024)
puts "\n\nComparing with 2024 (which works):"
temple_2024 = SearchableItem.where(year: 2024).where("name ILIKE ?", "%temple%").first
if temple_2024
  puts "2024 Temple: #{temple_2024.name}"
  puts "  Embedding size: #{temple_2024.embedding&.size}"
  puts "  Magnitude: #{Math.sqrt(temple_2024.embedding.sum { |v| v**2 }).round(4)}"
end

# Check if there's an index issue
puts "\n\nChecking indexes:"
sql = <<-SQL
  SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
  FROM pg_indexes
  WHERE tablename = 'searchable_items'
    AND indexname LIKE '%embedding%'
SQL

ActiveRecord::Base.connection.execute(sql).each do |row|
  puts "Index: #{row['indexname']}"
  puts "Definition: #{row['indexdef']}"
end