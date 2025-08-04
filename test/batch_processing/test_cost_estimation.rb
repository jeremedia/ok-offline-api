#!/usr/bin/env ruby
require_relative 'config/environment'

puts "💰 Testing Cost Estimation for Pool Entity Extraction"
puts "=" * 60

# Test with different batch sizes
test_sizes = [100, 1000, 10000, 54500]

service = Search::BatchPoolEntityExtractionService.new

test_sizes.each do |size|
  # Get sample items
  items = SearchableItem.limit(size)
  
  # Calculate estimate
  estimate = service.estimate_batch_cost(items)
  
  puts "\n📊 Batch size: #{size} items"
  puts "  Est. input tokens: #{estimate[:estimated_input_tokens].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
  puts "  Est. output tokens: #{estimate[:estimated_output_tokens].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
  puts "  Est. total tokens: #{estimate[:estimated_total_tokens].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
  puts "  💵 Estimated cost: #{estimate[:estimated_cost]}"
  puts "  📄 Cost per item: #{estimate[:cost_per_item]}"
end

# Calculate for all items needing pool entities
puts "\n" + "=" * 60
puts "🎯 Full Dataset Estimation"

items_needing_extraction = SearchableItem
  .joins("LEFT JOIN search_entities ON search_entities.searchable_item_id = searchable_items.id AND search_entities.entity_type LIKE 'pool_%'")
  .where("search_entities.id IS NULL")

count = items_needing_extraction.count
puts "\nItems needing pool extraction: #{count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"

if count > 0
  # Get actual items for accurate estimation
  sample_size = [count, 1000].min
  sample_items = items_needing_extraction.limit(sample_size)
  
  # Extrapolate from sample
  sample_estimate = service.estimate_batch_cost(sample_items)
  
  # Scale up estimate
  scale_factor = count.to_f / sample_size
  total_tokens = (sample_estimate[:estimated_total_tokens] * scale_factor).to_i
  total_cost = (sample_estimate[:estimated_cost].gsub('$','').to_f * scale_factor)
  
  puts "\n💰 Full extraction estimate:"
  puts "  Total items: #{count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
  puts "  Est. total tokens: #{total_tokens.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
  puts "  💵 Estimated total cost: $#{'%.2f' % total_cost}"
  puts "  📄 Average cost per item: $#{'%.6f' % (total_cost / count)}"
  
  # Batch breakdown
  batch_count = (count / 500.0).ceil
  puts "\n📦 Batch breakdown:"
  puts "  Number of batches (500 items each): #{batch_count}"
  puts "  Average cost per batch: $#{'%.2f' % (total_cost / batch_count)}"
end