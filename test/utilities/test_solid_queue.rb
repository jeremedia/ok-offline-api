#!/usr/bin/env ruby
require_relative 'config/environment'

puts "🧪 Testing Solid Queue Setup"
puts "=" * 60

# Check adapter
puts "\nActive Job Adapter: #{Rails.application.config.active_job.queue_adapter}"

# Test enqueuing a job
puts "\n📋 Enqueuing test job..."
job = ProcessBatchResultsJob.perform_later("test_batch_123")
puts "  Job ID: #{job.job_id}"
puts "  Queue: #{job.queue_name}"

# Check if job was enqueued
if defined?(SolidQueue)
  puts "\n✅ SolidQueue is loaded"
  
  # Check for jobs in queue
  if SolidQueue::Job.any?
    puts "  Jobs in queue: #{SolidQueue::Job.count}"
  end
else
  puts "\n⚠️  SolidQueue not loaded - jobs will use default adapter"
end

puts "\n💡 To start Solid Queue worker, run:"
puts "  bin/jobs"
puts "\nOr for development with auto-reload:"
puts "  bin/rails runner 'SolidQueue::Supervisor.start'"