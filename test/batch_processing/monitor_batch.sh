#!/bin/bash

echo "🔍 Monitoring Batch Processing Pipeline"
echo "======================================"
echo "Batch ID: batch_688e16b5867481908bd5ae7e1209cada"
echo ""
echo "Watching for:"
echo "  1. Webhook arrival"
echo "  2. Job queuing"
echo "  3. Processing completion"
echo ""
echo "Press Ctrl+C to stop monitoring"
echo "======================================"
echo ""

# Monitor logs for batch-related activity
tail -f log/development.log | grep -E --line-buffered "(webhook|Webhook|Batch|batch_688e16b5|Processing|🎉|🔄|✅|pool_)"