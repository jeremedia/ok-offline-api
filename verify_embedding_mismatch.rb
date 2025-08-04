#!/usr/bin/env ruby
require_relative 'config/environment'

puts "Verifying embedding version mismatch theory..."
puts "=" * 60

# Test: Generate a fresh embedding for a 2017 item and compare
temple_2017 = SearchableItem.where(year: 2017, name: "The Temple (2017)").first
if temple_2017
  puts "\nTesting with: #{temple_2017.name}"
  puts "Current stored embedding first 5: #{temple_2017.embedding.first(5).map { |v| v.round(4) }}"
  
  # Generate fresh embedding
  embedding_service = Search::EmbeddingService.new
  fresh_embedding = embedding_service.generate_embedding(temple_2017.searchable_text)
  
  if fresh_embedding
    puts "Fresh embedding first 5: #{fresh_embedding.first(5).map { |v| v.round(4) }}"
    
    # Compare
    if temple_2017.embedding.first(5) == fresh_embedding.first(5)
      puts "❌ Embeddings match - theory disproved"
    else
      puts "✅ Embeddings differ - confirms version mismatch!"
      
      # Calculate how different they are
      dot_product = temple_2017.embedding.zip(fresh_embedding).sum { |a, b| a * b }
      similarity = dot_product  # Both are normalized
      puts "Similarity between old and new embedding: #{similarity.round(4)}"
      puts "This should be ~1.0 if they were the same, but it's #{similarity < 0.9 ? 'significantly different!' : 'similar'}"
    end
  end
end

# Check when embeddings were created
puts "\n\nChecking embedding creation patterns:"
sql = <<-SQL
  SELECT 
    year,
    MIN(created_at) as first_created,
    MAX(created_at) as last_created,
    COUNT(*) as count
  FROM searchable_items
  WHERE embedding IS NOT NULL
  GROUP BY year
  ORDER BY year
SQL

results = ActiveRecord::Base.connection.execute(sql)
results.each do |row|
  puts "#{row['year']}: #{row['count']} items, created #{row['first_created'].to_s[0..9]} to #{row['last_created'].to_s[0..9]}"
end