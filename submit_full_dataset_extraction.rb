#!/usr/bin/env ruby
require_relative 'config/environment'

puts "🚀 FULL DATASET POOL ENTITY EXTRACTION"
puts "=" * 60

# Get all items that need pool entities
items_needing_pools = SearchableItem
  .joins("LEFT JOIN search_entities ON search_entities.searchable_item_id = searchable_items.id AND search_entities.entity_type LIKE 'pool_%'")
  .where("search_entities.id IS NULL")
  .where.not(description: nil)
  .where.not(description: '')
  .where("LENGTH(description) > 50")

total_items = items_needing_pools.count
puts "\n📊 Dataset Overview:"
puts "  Total items needing pools: #{total_items.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"

# Group by type
by_type = items_needing_pools.group(:item_type).count
puts "\n  By type:"
by_type.each do |type, count|
  puts "    - #{type}: #{count.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
end

# Cost estimation
service = Search::BatchPoolEntityExtractionService.new
batch_size = Search::BatchPoolEntityExtractionService::BATCH_SIZE
num_batches = (total_items.to_f / batch_size).ceil
estimated_tokens = total_items * 700 # ~700 tokens per item average
estimated_cost = (estimated_tokens / 1_000_000.0) * 0.20 * 2 # input + output

puts "\n💰 Cost Estimate:"
puts "  Batch size: #{batch_size} items"
puts "  Number of batches: #{num_batches}"
puts "  Estimated tokens: ~#{(estimated_tokens / 1_000_000.0).round(1)}M"
puts "  Estimated cost: $#{'%.2f' % estimated_cost}"
puts "  Cost per item: $#{'%.4f' % (estimated_cost / total_items)}"

# Check existing batches
existing_batches = BatchJob.where(status: ['pending', 'in_progress']).count
if existing_batches > 0
  puts "\n⚠️  WARNING: #{existing_batches} batches are still pending/in_progress"
  puts "   Consider waiting for these to complete first."
end

# Safety check
puts "\n🔐 Safety Checks:"
puts "  ✓ OpenAI API Key: #{ENV['OPENAI_API_KEY'].present? ? 'Set' : 'MISSING!'}"
puts "  ✓ Webhook Secret: #{ENV['OPENAI_WEBHOOK_SECRET'].present? ? 'Set' : 'MISSING!'}"
puts "  ✓ Solid Queue: #{SolidQueue::Job.count} jobs in queue"
puts "  ✓ Database: #{ActiveRecord::Base.connection.active? ? 'Connected' : 'NOT CONNECTED!'}"

# Final confirmation
puts "\n❓ Ready to submit #{total_items.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} items in #{num_batches} batches?"
puts "   Estimated cost: $#{'%.2f' % estimated_cost}"
puts "   This will take 1-24 hours to complete."
puts "\n   Type 'yes' to proceed, anything else to cancel:"

response = gets.chomp.downcase

if response == 'yes'
  puts "\n🚀 Starting batch submission..."
  puts "   This may take several minutes..."
  
  start_time = Time.current
  
  # Submit in batches
  batch_ids = service.submit_batch_extraction(items_needing_pools)
  
  end_time = Time.current
  duration = (end_time - start_time).round(1)
  
  if batch_ids.any?
    puts "\n✅ Successfully submitted #{batch_ids.count} batches!"
    puts "   Submission took #{duration} seconds"
    puts "\n📋 Batch IDs:"
    
    batch_ids.each_with_index do |batch_id, idx|
      batch_job = BatchJob.find_by(batch_id: batch_id)
      puts "   #{idx + 1}. #{batch_id} (#{batch_job.total_items} items)"
    end
    
    puts "\n📊 Next Steps:"
    puts "   1. Monitor progress: rails batches:status"
    puts "   2. Check costs: rails batches:costs"
    puts "   3. Watch logs: tail -f log/development.log | grep -E '(webhook|Processing|batch_)'"
    puts "   4. Webhooks will trigger automatic processing as batches complete"
    
    puts "\n💡 Created monitoring script: monitor_all_batches.sh"
    
    # Create monitoring script
    File.write('monitor_all_batches.sh', <<~BASH)
      #!/bin/bash
      echo "🔍 Monitoring All Active Batches"
      echo "================================"
      
      while true; do
        clear
        echo "🔍 Batch Processing Status - $(date)"
        echo "================================"
        echo ""
        
        rails runner "
          active = BatchJob.where(status: ['pending', 'in_progress', 'validating', 'finalizing'])
          completed = BatchJob.where(status: 'completed')
          
          puts 'Active Batches: ' + active.count.to_s
          puts 'Completed: ' + completed.count.to_s
          puts ''
          
          active.order(:id).each do |b|
            puts 'Batch ' + b.id.to_s + ': ' + b.status + ' (' + b.total_items.to_s + ' items)'
          end
          
          puts ''
          puts 'Total cost so far: $' + sprintf('%.2f', completed.sum(:total_cost))
        "
        
        sleep 30
      done
    BASH
    
    File.chmod(0755, 'monitor_all_batches.sh')
    
    puts "\n🎉 Full dataset extraction initiated!"
  else
    puts "\n❌ Failed to submit batches"
  end
else
  puts "\n❌ Batch submission cancelled"
end