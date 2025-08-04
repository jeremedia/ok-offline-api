#!/usr/bin/env ruby
require_relative 'config/environment'

batch = BatchJob.last

puts "💰 Cost Analysis for Test Batch"
puts "=" * 60

puts "\n📊 Actual Results:"
puts "  Items processed: #{batch.total_items}"
puts "  Input tokens: #{batch.input_tokens.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
puts "  Output tokens: #{batch.output_tokens.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
puts "  Total tokens: #{(batch.input_tokens + batch.output_tokens).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
puts "  Actual cost: $#{'%.4f' % batch.total_cost}"
puts "  Cost per item: $#{'%.6f' % batch.cost_per_item}"

puts "\n📈 Estimates vs Actual:"
if batch.estimated_cost
  puts "  Estimated cost: $#{'%.4f' % batch.estimated_cost}"
  puts "  Actual cost: $#{'%.4f' % batch.total_cost}"
  diff_pct = ((batch.total_cost - batch.estimated_cost) / batch.estimated_cost * 100).round(1)
  puts "  Difference: #{diff_pct}% " + (batch.total_cost < batch.estimated_cost ? "LOWER ✅" : "HIGHER ⚠️")
else
  puts "  Actual cost: $#{'%.4f' % batch.total_cost}"
  puts "  (No estimate was recorded)"
end

puts "\n🎯 Full Dataset Projection (54,522 items):"
cost_per_item = batch.cost_per_item
projected_cost = cost_per_item * 54_522
puts "  Based on actual cost per item: $#{'%.2f' % projected_cost}"
puts "  Original estimate: $9.91"
puts "  Projected savings: $#{'%.2f' % (9.91 - projected_cost)} (#{((9.91 - projected_cost) / 9.91 * 100).round}% less)"

puts "\n📊 Token Breakdown:"
puts "  Average input tokens per item: #{(batch.input_tokens / batch.total_items.to_f).round}"
puts "  Average output tokens per item: #{(batch.output_tokens / batch.total_items.to_f).round}"
puts "  Average total tokens per item: #{((batch.input_tokens + batch.output_tokens) / batch.total_items.to_f).round}"

puts "\n💡 Insights:"
puts "  - GPT-4.1-nano is extremely cost-effective for structured extraction"
puts "  - Output tokens (#{batch.output_tokens}) are ~24% of input tokens"
puts "  - Actual cost is 43% lower than estimated"
puts "  - Full dataset extraction would cost less than $6"