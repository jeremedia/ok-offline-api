namespace :batch do
  desc "Monitor all active batches"
  task monitor: :environment do
    puts "🔍 Monitoring Active Batches"
    puts "=" * 80
    puts "Timestamp: #{Time.now}"
    
    # Track batch IDs in a file for persistence
    batch_file = Rails.root.join('tmp', 'active_batches.txt')
    
    if File.exist?(batch_file)
      batch_ids = File.read(batch_file).split("\n").reject(&:empty?)
      
      if batch_ids.empty?
        puts "\n📭 No active batches to monitor"
        puts "\nTo add a batch: rails batch:track[batch_id]"
        exit
      end
      
      service = Search::BatchPoolEntityExtractionService.new
      
      batch_ids.each_with_index do |batch_id, index|
        puts "\n#{index + 1}. Batch: #{batch_id}"
        puts "-" * 60
        
        begin
          status = service.check_batch_status(batch_id)
          
          # Display status
          case status[:status]
          when 'completed'
            puts "  ✅ Status: COMPLETED"
          when 'failed'
            puts "  ❌ Status: FAILED"
          when 'in_progress'
            puts "  ⏳ Status: IN PROGRESS"
          else
            puts "  🔄 Status: #{status[:status].upcase}"
          end
          
          # Time info
          puts "  ⏰ Created: #{status[:created_at]}"
          if status[:completed_at]
            duration = status[:completed_at] - status[:created_at]
            puts "  ✓ Completed: #{status[:completed_at]} (took #{(duration / 60).round} minutes)"
          else
            elapsed = Time.now - status[:created_at]
            puts "  ⏱️  Elapsed: #{(elapsed / 60).round} minutes"
          end
          
          # Progress
          if status[:request_counts]
            completed = status[:request_counts]['completed'] || 0
            total = status[:request_counts]['total'] || 0
            failed = status[:request_counts]['failed'] || 0
            
            if total > 0
              percentage = (completed.to_f / total * 100).round(1)
              progress_bar = "█" * (percentage / 5).to_i + "░" * (20 - (percentage / 5).to_i)
              puts "  📊 Progress: [#{progress_bar}] #{percentage}% (#{completed}/#{total})"
              puts "  ❌ Failed: #{failed}" if failed > 0
            end
          end
          
          # Cost info (only if completed)
          if status[:status] == 'completed' && status[:usage]
            puts "  💰 Cost: #{status[:usage][:estimated_cost][:total_cost]} (#{status[:usage][:total_tokens].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} tokens)"
          end
          
        rescue => e
          puts "  ❌ Error checking batch: #{e.message}"
        end
      end
      
      # Summary
      puts "\n" + "=" * 80
      puts "💡 Tips:"
      puts "  - Add batch: rails batch:track[batch_id]"
      puts "  - Remove batch: rails batch:untrack[batch_id]"
      puts "  - Process completed: rails search:process_batch_results[batch_id]"
      puts "  - Auto-refresh: watch -n 60 'rails batch:monitor'"
      
    else
      puts "\n📭 No batches being tracked"
      puts "\nTo start tracking a batch:"
      puts "  rails batch:track[batch_id]"
    end
  end
  
  desc "Add a batch to monitoring"
  task :track, [:batch_id] => :environment do |t, args|
    batch_id = args[:batch_id]
    
    unless batch_id
      puts "❌ Please provide a batch ID"
      exit
    end
    
    batch_file = Rails.root.join('tmp', 'active_batches.txt')
    
    # Read existing batches
    existing = File.exist?(batch_file) ? File.read(batch_file).split("\n") : []
    
    if existing.include?(batch_id)
      puts "⚠️  Batch #{batch_id} is already being tracked"
    else
      existing << batch_id
      File.write(batch_file, existing.join("\n"))
      puts "✅ Added batch #{batch_id} to monitoring"
    end
  end
  
  desc "Remove a batch from monitoring"
  task :untrack, [:batch_id] => :environment do |t, args|
    batch_id = args[:batch_id]
    
    unless batch_id
      puts "❌ Please provide a batch ID"
      exit
    end
    
    batch_file = Rails.root.join('tmp', 'active_batches.txt')
    
    if File.exist?(batch_file)
      existing = File.read(batch_file).split("\n")
      existing.delete(batch_id)
      File.write(batch_file, existing.join("\n"))
      puts "✅ Removed batch #{batch_id} from monitoring"
    else
      puts "❌ No batches are being tracked"
    end
  end
  
  desc "Auto-process completed batches"
  task autoprocess: :environment do
    batch_file = Rails.root.join('tmp', 'active_batches.txt')
    
    if File.exist?(batch_file)
      batch_ids = File.read(batch_file).split("\n").reject(&:empty?)
      service = Search::BatchPoolEntityExtractionService.new
      
      batch_ids.each do |batch_id|
        status = service.check_batch_status(batch_id)
        
        if status[:status] == 'completed'
          puts "🔄 Processing completed batch: #{batch_id}"
          
          success = service.process_batch_results(batch_id)
          
          if success
            # Remove from tracking
            Rake::Task['batch:untrack'].invoke(batch_id)
            Rake::Task['batch:untrack'].reenable
          end
        end
      end
    end
  end
end