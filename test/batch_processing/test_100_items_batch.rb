#!/usr/bin/env ruby
require_relative 'config/environment'

puts "🚀 Testing 100-Item Batch Processing"
puts "=" * 60

# Get 100 items that need pool entities
test_items = SearchableItem
  .joins("LEFT JOIN search_entities ON search_entities.searchable_item_id = searchable_items.id AND search_entities.entity_type LIKE 'pool_%'")
  .where("search_entities.id IS NULL")
  .where.not(description: nil)
  .where.not(description: '')
  .where("LENGTH(description) > 50")
  .limit(100)

if test_items.count < 100
  puts "⚠️  Only found #{test_items.count} items that need pool entities"
  puts "   Continuing with available items..."
end

puts "\n📄 Test Items: #{test_items.count}"
puts "  Item types:"
test_items.group(:item_type).count.each do |type, count|
  puts "    - #{type}: #{count}"
end

# Estimate cost
service = Search::BatchPoolEntityExtractionService.new
estimated_tokens = test_items.count * 700 # ~700 tokens per item average
estimated_cost = (estimated_tokens / 1_000_000.0) * 0.20 * 2 # input + output

puts "\n💰 Cost Estimate:"
puts "  Items: #{test_items.count}"
puts "  Estimated tokens: ~#{estimated_tokens.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
puts "  Estimated cost: $#{'%.4f' % estimated_cost}"

# Check Solid Queue
puts "\n📋 Solid Queue Status:"
pending_jobs = SolidQueue::Job.where(finished_at: nil).count
puts "  Pending jobs: #{pending_jobs}"
puts "  Worker status: #{pending_jobs > 0 ? '⚠️  Check if bin/jobs is running' : '✅ Ready'}"

# Confirm before proceeding
puts "\n❓ Ready to submit batch? (y/n)"
response = gets.chomp.downcase

if response != 'y'
  puts "❌ Batch cancelled"
  exit
end

# Submit batch
puts "\n🚀 Submitting #{test_items.count}-item batch..."
batch_ids = service.submit_batch_extraction(test_items)

if batch_ids.any?
  batch_id = batch_ids.first
  batch_job = BatchJob.find_by(batch_id: batch_id)
  
  puts "\n✅ Batch submitted successfully!"
  puts "  Batch ID: #{batch_id}"
  puts "  Database ID: #{batch_job.id}"
  puts "  Status: #{batch_job.status}"
  puts "  Estimated cost: $#{'%.4f' % batch_job.estimated_cost}"
  
  puts "\n🤖 Automation Pipeline Active:"
  puts "  1. ⏳ OpenAI processing batch (est. 2-10 minutes)"
  puts "  2. 🔔 Webhook will trigger when complete"
  puts "  3. 🔄 ProcessBatchResultsJob will run automatically"
  puts "  4. 🌊 Pool entities will be extracted"
  puts "  5. 💰 Actual costs will be tracked"
  
  puts "\n📊 Monitor progress:"
  puts "  - Quick status: rails runner 'p BatchJob.find(#{batch_job.id}).status'"
  puts "  - Watch logs: tail -f log/development.log | grep -E '(batch_#{batch_id[0,10]}|webhook|Processing)'"
  puts "  - Full details: rails runner 'load \"verify_automation.rb\"' (after completion)"
  
  # Create monitoring script
  File.write("monitor_batch_#{batch_job.id}.sh", <<~BASH)
    #!/bin/bash
    echo "🔍 Monitoring Batch #{batch_job.id} (#{batch_id})"
    echo "================================================"
    while true; do
      status=$(rails runner "puts BatchJob.find(#{batch_job.id}).status" 2>/dev/null)
      processed=$(rails runner "puts BatchJob.find(#{batch_job.id}).metadata['processed'] ? 'Yes' : 'No'" 2>/dev/null)
      echo -ne "\\r⏱️  Status: $status | Processed: $processed | $(date +%H:%M:%S)"
      if [[ "$status" == "completed" && "$processed" == "Yes" ]]; then
        echo -e "\\n✅ Batch processing complete!"
        rails runner "b = BatchJob.find(#{batch_job.id}); puts '  Cost: $' + sprintf('%.4f', b.total_cost); puts '  Items: ' + b.total_items.to_s"
        break
      fi
      sleep 5
    done
  BASH
  
  File.chmod(0755, "monitor_batch_#{batch_job.id}.sh")
  puts "\n💡 Run ./monitor_batch_#{batch_job.id}.sh to watch progress"
else
  puts "\n❌ Failed to submit batch"
end