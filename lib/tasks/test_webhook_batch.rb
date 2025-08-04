#!/usr/bin/env ruby
require_relative '../../config/environment'

# Test the complete webhook-enabled batch workflow
class WebhookBatchTester
  def initialize
    @batch_service = Search::BatchEmbeddingService.new
  end
  
  def run_test
    puts "🔗 Testing Webhook-Enabled Batch Workflow"
    puts "=" * 50
    
    # Check prerequisites
    unless check_prerequisites
      return
    end
    
    # Get test items
    test_items = SearchableItem.where(embedding: nil).limit(3)
    
    if test_items.empty?
      puts "❌ No items without embeddings found for testing"
      return
    end
    
    puts "📋 Test Items:"
    test_items.each_with_index do |item, i|
      puts "   #{i+1}. #{item.name} (#{item.item_type}, #{item.year})"
      puts "      ID: #{item.id}"
      puts "      Text: #{item.searchable_text[0..80]}..."
    end
    
    puts "\n🚀 Creating batch job with webhook support..."
    
    # Create batch job
    begin
      result = @batch_service.queue_batch_job(
        test_items, 
        description: "Test webhook batch (#{test_items.count} items)"
      )
      
      openai_batch_id = result[:openai_batch_id]
      local_batch_id = result[:local_batch_id]
      
      puts "✅ Batch job created successfully!"
      puts "   OpenAI Batch ID: #{openai_batch_id}"
      puts "   Local Batch ID: #{local_batch_id}"
      puts "   Items: #{result[:item_count]}"
      
      puts "\n📡 Webhook endpoint ready at:"
      puts "   #{webhook_url}"
      
      puts "\n⏰ Expected workflow:"
      puts "   1. OpenAI processes batch (up to 24 hours)"
      puts "   2. OpenAI sends webhook to #{webhook_url}"
      puts "   3. Webhook triggers BatchCompletionJob"
      puts "   4. Job downloads results and updates embeddings"
      
      puts "\n🔍 Monitor batch status:"
      puts "   OpenAI Console: https://platform.openai.com/batches/#{openai_batch_id}"
      puts "   Local cache: rails runner \"puts Rails.cache.read('batch_#{local_batch_id}').inspect\""
      
      puts "\n📊 Manual status check:"
      puts "   rails runner \"puts OpenAI::Client.new(api_key: ENV['OPENAI_API_KEY']).batches.retrieve('#{openai_batch_id}').inspect\""
      
    rescue => e
      puts "❌ Failed to create batch job: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end
  
  def check_existing_batches
    puts "\n📋 Recent Batch Jobs:"
    
    begin
      client = OpenAI::Client.new(api_key: ENV['OPENAI_API_KEY'])
      batches = client.batches.list(parameters: { limit: 5 })
      
      if batches['data'].empty?
        puts "   No recent batches found"
        return
      end
      
      batches['data'].each do |batch|
        status_emoji = case batch['status']
                      when 'completed' then '✅'
                      when 'failed' then '❌'
                      when 'in_progress' then '🔄'
                      when 'validating' then '⏳'
                      when 'expired' then '⏰'
                      else '📊'
                      end
        
        description = batch.dig('metadata', 'description') || 'No description'
        
        puts "   #{status_emoji} #{batch['id']} (#{batch['status']})"
        puts "      #{description}"
        puts "      Created: #{Time.at(batch['created_at']).strftime('%Y-%m-%d %H:%M')}"
        
        if batch['request_counts']['total'] > 0
          puts "      Progress: #{batch['request_counts']['completed']}/#{batch['request_counts']['total']}"
        end
        
        puts ""
      end
      
    rescue => e
      puts "   ❌ Failed to list batches: #{e.message}"
    end
  end
  
  private
  
  def check_prerequisites
    errors = []
    
    # Check API key
    unless ENV['OPENAI_API_KEY']
      errors << "OPENAI_API_KEY not set"
    end
    
    # Check webhook secret
    unless ENV['OPENAI_WEBHOOK_SECRET']
      errors << "OPENAI_WEBHOOK_SECRET not set"
    end
    
    # Check webhook URL is accessible
    webhook_reachable = check_webhook_accessibility
    unless webhook_reachable
      errors << "Webhook endpoint not accessible from internet"
    end
    
    if errors.any?
      puts "❌ Prerequisites not met:"
      errors.each { |error| puts "   - #{error}" }
      
      puts "\n🔧 Setup instructions:"
      puts "   1. Set OPENAI_API_KEY in your environment"
      puts "   2. Set OPENAI_WEBHOOK_SECRET (get from OpenAI dashboard)"
      puts "   3. Make sure your Rails server is accessible from the internet"
      puts "   4. Configure webhook endpoint in OpenAI dashboard:"
      puts "      - URL: #{webhook_url}"
      puts "      - Events: batch.completed, batch.failed, batch.expired"
      
      return false
    end
    
    puts "✅ Prerequisites check passed"
    return true
  end
  
  def webhook_url
    # In development, you might use ngrok or similar
    # In production, use your actual domain
    base_url = ENV['WEBHOOK_BASE_URL'] || 'https://your-domain.com'
    "#{base_url}/api/v1/webhooks/openai_batch"
  end
  
  def check_webhook_accessibility
    # Simple check - in production you'd want to verify the webhook URL
    # is actually reachable from the internet
    ENV['WEBHOOK_BASE_URL'].present?
  end
end

# Run the test
if __FILE__ == $0
  tester = WebhookBatchTester.new
  tester.check_existing_batches
  
  puts "\n" + "="*50
  puts "🤔 Create a test batch with webhook support? (y/N)"
  puts "   This will create a real batch job that costs ~$0.0001"
  
  # For now, just show what would happen
  puts "\nTo run the test:"
  puts "1. Set WEBHOOK_BASE_URL environment variable"
  puts "2. Configure webhook in OpenAI dashboard" 
  puts "3. Run: ruby lib/tasks/test_webhook_batch.rb"
  puts "4. Answer 'y' when prompted"
  
  # Uncomment to run interactively:
  # response = STDIN.gets.chomp.downcase
  # if response == 'y' || response == 'yes'
  #   tester.run_test
  # end
end