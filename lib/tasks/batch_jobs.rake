namespace :batches do
  desc "Show all batch jobs with detailed status"
  task status: :environment do
    puts "📊 Batch Jobs Status"
    puts "=" * 100
    puts "Generated: #{Time.current.strftime('%Y-%m-%d %H:%M:%S %Z')}"
    
    # Active batches
    active = BatchJob.active.recent
    if active.any?
      puts "\n🟢 Active Batches (#{active.count})"
      puts "-" * 100
      display_batch_table(active, detailed: true)
    end
    
    # Recently completed
    recent_completed = BatchJob.completed.where('completed_at > ?', 24.hours.ago).recent
    if recent_completed.any?
      puts "\n✅ Recently Completed (last 24h)"
      puts "-" * 100
      display_batch_table(recent_completed)
    end
    
    # Failed batches
    failed = BatchJob.failed.recent.limit(5)
    if failed.any?
      puts "\n❌ Failed Batches (recent)"
      puts "-" * 100
      display_batch_table(failed, show_errors: true)
    end
    
    # Summary statistics
    puts "\n📈 Overall Statistics"
    puts "-" * 100
    
    total_batches = BatchJob.count
    total_completed = BatchJob.completed.count
    total_cost = BatchJob.completed.sum(:total_cost)
    total_items = BatchJob.completed.sum(:total_items)
    
    puts "Total batches: #{total_batches}"
    puts "Completed: #{total_completed}"
    puts "Total cost: $#{'%.4f' % total_cost}" if total_cost > 0
    puts "Total items processed: #{total_items.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts "Average cost per item: $#{'%.6f' % (total_cost / total_items)}" if total_items > 0
  end
  
  desc "Sync all active batches with OpenAI API"
  task sync: :environment do
    puts "🔄 Syncing active batches..."
    
    service = Search::BatchPoolEntityExtractionService.new
    active_batches = BatchJob.active
    
    active_batches.each do |batch|
      print "  Checking #{batch.batch_id}... "
      begin
        service.check_batch_status(batch.batch_id)
        puts "✓"
      rescue => e
        puts "✗ (#{e.message})"
      end
    end
    
    puts "✅ Sync complete"
  end
  
  desc "Import existing batch by ID"
  task :import, [:batch_id] => :environment do |t, args|
    batch_id = args[:batch_id]
    
    unless batch_id
      puts "❌ Please provide a batch ID"
      exit
    end
    
    # Check if already exists
    if BatchJob.exists?(batch_id: batch_id)
      puts "⚠️  Batch #{batch_id} already in database"
      exit
    end
    
    service = Search::BatchPoolEntityExtractionService.new
    
    begin
      puts "📥 Importing batch #{batch_id}..."
      response = service.check_batch_status(batch_id)
      
      # Create record
      batch = BatchJob.create!(
        batch_id: batch_id,
        job_type: 'pool_extraction', # Default, update if needed
        status: response[:status],
        total_items: response[:request_counts]&.dig('total') || 0,
        completed_items: response[:request_counts]&.dig('completed') || 0,
        failed_items: response[:request_counts]&.dig('failed') || 0,
        created_at: response[:created_at]
      )
      
      puts "✅ Imported successfully"
      puts "  Status: #{batch.status}"
      puts "  Progress: #{batch.progress_percentage}%"
      
    rescue => e
      puts "❌ Failed to import: #{e.message}"
    end
  end
  
  desc "Auto-process completed batches"
  task autoprocess: :environment do
    service = Search::BatchPoolEntityExtractionService.new
    
    # Find completed batches that haven't been processed
    completed = BatchJob.completed.where("metadata->>'processed' IS NULL OR metadata->>'processed' = 'false'")
    
    if completed.empty?
      puts "✅ No completed batches to process"
      exit
    end
    
    completed.each do |batch|
      puts "🔄 Processing batch #{batch.batch_id}..."
      
      begin
        success = service.process_batch_results(batch.batch_id)
        
        if success
          batch.metadata['processed'] = true
          batch.metadata['processed_at'] = Time.current
          batch.save!
          puts "  ✅ Processed successfully"
        else
          puts "  ❌ Processing failed"
        end
      rescue => e
        puts "  ❌ Error: #{e.message}"
      end
    end
  end
  
  private
  
  def display_batch_table(batches, detailed: false, show_errors: false)
    batches.each do |batch|
      puts "\n#{status_icon(batch.status)} Batch: #{batch.batch_id}"
      puts "  Type: #{batch.job_type.humanize}"
      puts "  Status: #{batch.status.upcase}"
      
      if batch.in_progress? && detailed
        puts "  Progress: #{progress_bar(batch.progress_percentage)} #{batch.progress_percentage}% (#{batch.completed_items}/#{batch.total_items})"
        puts "  Duration: #{batch.duration_in_words || 'Just started'}"
        
        if batch.estimated_completion_time
          puts "  ETA: #{batch.estimated_completion_time.strftime('%H:%M')} (#{time_remaining(batch.estimated_completion_time)})"
        end
      elsif batch.completed?
        puts "  Items: #{batch.total_items} (#{batch.failed_items} failed)" if batch.failed_items > 0
        puts "  Duration: #{batch.duration_in_words}"
        puts "  Cost: $#{'%.4f' % batch.total_cost} ($#{'%.6f' % batch.cost_per_item}/item)" if batch.total_cost
      end
      
      if show_errors && batch.error_message.present?
        puts "  Error: #{batch.error_message.truncate(100)}"
      end
      
      puts "  Created: #{batch.created_at.strftime('%Y-%m-%d %H:%M')}"
    end
  end
  
  def status_icon(status)
    case status
    when 'pending' then '⏸️'
    when 'in_progress' then '⏳'
    when 'completed' then '✅'
    when 'failed' then '❌'
    when 'cancelled' then '🚫'
    else '❓'
    end
  end
  
  def progress_bar(percentage)
    filled = (percentage / 5).to_i
    empty = 20 - filled
    '█' * filled + '░' * empty
  end
  
  def time_remaining(eta)
    seconds = (eta - Time.current).to_i
    return "Overdue" if seconds < 0
    
    if seconds < 60
      "#{seconds}s"
    elsif seconds < 3600
      "#{seconds / 60}m"
    else
      "#{(seconds / 3600.0).round(1)}h"
    end
  end
end