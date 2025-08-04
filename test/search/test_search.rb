#\!/usr/bin/env ruby
require_relative 'config/environment'

puts "🔍 Testing Semantic Search Functionality"
puts "=" * 50

# Test queries
test_queries = [
  "fire spinning and flow arts",
  "camps with shade and misting",
  "art cars that light up at night",
  "coffee and espresso in the morning",
  "deep playa art installations",
  "volunteer opportunities",
  "live music performances",
  "workshops about sustainability",
  "temple burn ceremony",
  "medical and safety services"
]

service = Search::VectorSearchService.new

test_queries.each do |query|
  puts "\n📍 Query: \"#{query}\""
  puts "-" * 40
  
  begin
    results = service.search(query: query, limit: 5)
    
    if results[:results].empty?
      puts "   No results found"
    else
      results[:results].each_with_index do |item, index|
        puts "   #{index + 1}. [#{item[:item_type]}] #{item[:name]}"
        puts "      Score: #{item[:similarity_score]&.round(4) || 'N/A'}"
        puts "      Year: #{item[:year]}"
        puts "      Description: #{item[:description].to_s.truncate(100)}" if item[:description]
      end
    end
    puts "   Execution time: #{results[:execution_time].round(3)}s"
  rescue => e
    puts "   ❌ Error: #{e.message}"
    puts "   #{e.backtrace.first}"
  end
end

# Check embedding coverage by year
puts "\n\n📊 Embedding Coverage by Year:"
puts "-" * 40

by_year = SearchableItem.group(:year)
                       .pluck(:year, 
                              Arel.sql('COUNT(*)'), 
                              Arel.sql('COUNT(CASE WHEN embedding IS NOT NULL THEN 1 END)'))
                       .sort_by(&:first)

by_year.each do |year, total, with_embeddings|
  percentage = (with_embeddings.to_f / total * 100).round(1)
  bar_length = (percentage / 2).to_i
  bar = "█" * bar_length + "░" * (50 - bar_length)
  
  puts "   #{year}: [#{bar}] #{percentage}% (#{with_embeddings}/#{total})"
end

puts "\n✅ Search test complete\!"
