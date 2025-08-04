#!/usr/bin/env ruby
require_relative 'config/environment'

puts "Testing 2017 search with text-embedding-3-small model..."
puts "=" * 60

# Generate fresh embedding with 3-small model
embedding_service = Search::EmbeddingService.new
query = "2017 temple"
puts "\nGenerating embedding for: '#{query}'"
fresh_embedding = embedding_service.generate_embedding(query)

if fresh_embedding.nil?
  puts "❌ Failed to generate embedding!"
  exit 1
end

puts "✅ Generated embedding with #{Search::EmbeddingService::EMBEDDING_MODEL}"
puts "   Embedding size: #{fresh_embedding.size}"
puts "   First 5 values: #{fresh_embedding.first(5).map { |v| v.round(4) }}"

# Test search on 2017
puts "\nSearching 2017 items using fresh embedding..."
results = SearchableItem
  .where(year: 2017)
  .nearest_neighbors(:embedding, fresh_embedding, distance: "cosine")
  .limit(10)
  .to_a

puts "Found #{results.length} results:"

if results.any?
  results.each_with_index do |item, i|
    # Calculate distance manually
    distance = 1 - fresh_embedding.zip(item.embedding).sum { |a, b| a * b }
    puts "  #{i+1}. #{item.name}"
    puts "     Type: #{item.item_type}"
    puts "     Distance: #{distance.round(4)}"
    puts "     Has 'temple': #{item.name.downcase.include?('temple')}"
    puts ""
  end
else
  puts "❌ No results found!"
  
  # Let's check if there are any 2017 items at all
  total_2017 = SearchableItem.where(year: 2017).count
  with_embeddings_2017 = SearchableItem.where(year: 2017).where.not(embedding: nil).count
  
  puts "\nDiagnostics:"
  puts "  Total 2017 items: #{total_2017}"
  puts "  2017 items with embeddings: #{with_embeddings_2017}"
  
  if with_embeddings_2017 > 0
    # Test with a very broad search (no year filter)
    puts "\n  Testing broader search (all years):"
    broad_results = SearchableItem
      .nearest_neighbors(:embedding, fresh_embedding, distance: "cosine")
      .limit(5)
      .to_a
    
    broad_results.each do |item|
      puts "    - #{item.name} (#{item.year})"
    end
  end
end

# Compare old vs new embedding on a 2017 item
puts "\n" + "=" * 60
puts "Comparing stored vs fresh embeddings on 2017 temple:"

temple_2017 = SearchableItem.where(year: 2017).where("name ILIKE ?", "%temple%").first
if temple_2017
  puts "\nTesting with: #{temple_2017.name}"
  
  # Generate fresh embedding for this specific item
  item_fresh_embedding = embedding_service.generate_embedding(temple_2017.searchable_text)
  
  if item_fresh_embedding
    # Compare stored vs fresh
    similarity = temple_2017.embedding.zip(item_fresh_embedding).sum { |a, b| a * b }
    puts "Stored embedding first 5: #{temple_2017.embedding.first(5).map { |v| v.round(4) }}"
    puts "Fresh embedding first 5:  #{item_fresh_embedding.first(5).map { |v| v.round(4) }}"
    puts "Similarity: #{similarity.round(6)}"
    
    if similarity > 0.9
      puts "✅ Embeddings are compatible (similarity > 0.9)"
    else
      puts "❌ Embeddings are incompatible (similarity = #{similarity.round(6)})"
      puts "   This confirms the model mismatch issue!"
    end
  end
end