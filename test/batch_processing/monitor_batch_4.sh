#!/bin/bash
echo "🔍 Monitoring Batch 4 (batch_688e1900e0548190b4c2da9293e7824e)"
echo "================================================"
while true; do
  status=$(rails runner "puts BatchJob.find(4).status" 2>/dev/null)
  processed=$(rails runner "puts BatchJob.find(4).metadata['processed'] ? 'Yes' : 'No'" 2>/dev/null)
  echo -ne "\r⏱️  Status: $status | Processed: $processed | $(date +%H:%M:%S)"
  if [[ "$status" == "completed" && "$processed" == "Yes" ]]; then
    echo -e "\n✅ Batch processing complete!"
    rails runner "b = BatchJob.find(4); puts '  Cost: $' + sprintf('%.4f', b.total_cost); puts '  Items: ' + b.total_items.to_s"
    break
  fi
  sleep 5
done
