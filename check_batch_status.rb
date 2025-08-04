#!/usr/bin/env ruby
require_relative 'config/environment'

puts "=== Batch Job Status ==="
puts "Total batch jobs: #{BatchJob.count}"
puts "Completed: #{BatchJob.where(status: 'completed').count}"
puts "Failed: #{BatchJob.where(status: 'failed').count}"
puts "Processing: #{BatchJob.where(status: 'in_progress').count}"

if BatchJob.where(status: 'failed').any?
  puts "\nFailed batches:"
  BatchJob.where(status: 'failed').each do |batch|
    puts "  #{batch.batch_id}: #{batch.error_message}"
  end
end

puts "\n=== Pool Entity Statistics ==="
pool_types = SearchEntity.where("entity_type LIKE 'pool_%'").distinct.pluck(:entity_type).sort
pool_types.each do |pool_type|
  count = SearchEntity.where(entity_type: pool_type).count
  puts "  #{pool_type}: #{count} entities"
end

total_entities = SearchEntity.where("entity_type LIKE 'pool_%'").count
puts "\nTotal pool entities: #{total_entities}"