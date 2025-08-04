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
    
    if active.count > 0
      puts 'Active batch details:'
      active.order(:id).limit(10).each do |b|
        puts '  Batch ' + b.id.to_s + ': ' + b.status + ' (' + b.total_items.to_s + ' items)'
      end
      
      if active.count > 10
        puts '  ... and ' + (active.count - 10).to_s + ' more'
      end
    end
    
    puts ''
    puts 'Progress: ' + completed.sum(:total_items).to_s + ' / ' + BatchJob.sum(:total_items).to_s + ' items processed'
    puts 'Total cost so far: $' + sprintf('%.2f', completed.sum(:total_cost))
    puts 'Estimated total: $' + sprintf('%.2f', BatchJob.sum(:estimated_cost))
  "
  
  sleep 30
done