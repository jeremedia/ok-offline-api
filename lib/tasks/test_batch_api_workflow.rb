#!/usr/bin/env ruby
require_relative '../../config/environment'

# Test the complete Batch API workflow with OpenAI
class BatchApiTester
  def initialize
    @client = OpenAI::Client.new(
      api_key: ENV['OPENAI_API_KEY'],
      timeout: 240
    )
  end
  
  def run_test
    puts "🧪 Testing OpenAI Batch API Workflow"
    puts "=" * 50
    
    # Check API key
    unless ENV['OPENAI_API_KEY']
      puts "❌ OPENAI_API_KEY not set - cannot test Batch API"
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
    
    puts "\n🔧 Testing Batch API workflow..."
    
    # Step 1: Create JSONL file
    batch_file = create_batch_file(test_items)
    return unless batch_file
    
    # Step 2: Upload file to OpenAI
    file_id = upload_batch_file(batch_file)
    return unless file_id
    
    # Step 3: Create batch job
    batch_id = create_batch_job(file_id)
    return unless batch_id
    
    # Step 4: Check status
    check_batch_status(batch_id)
    
    # Clean up temp file
    File.delete(batch_file) if File.exist?(batch_file)
    
    puts "\n✅ Batch API test completed successfully!"
    puts "📝 Batch ID: #{batch_id}"
    puts "⏰ Check status with: rails runner \"puts OpenAI::Client.new(api_key: ENV['OPENAI_API_KEY']).batches.retrieve('#{batch_id}')\""
  end
  
  private
  
  def create_batch_file(items)
    batch_id = SecureRandom.hex(6)
    batch_file = Rails.root.join('tmp', "batch_test_#{batch_id}.jsonl")
    
    puts "📝 Creating JSONL file..."
    
    begin
      File.open(batch_file, 'w') do |file|
        items.each do |item|
          request = {
            custom_id: "item_#{item.id}",
            method: "POST",
            url: "/v1/embeddings",
            body: {
              model: "text-embedding-3-small",
              input: item.searchable_text,
              dimensions: 1536
            }
          }
          file.puts request.to_json
        end
      end
      
      file_size = File.size(batch_file)
      line_count = File.readlines(batch_file).count
      puts "   ✅ Created #{batch_file}"
      puts "   📊 Size: #{file_size} bytes, Lines: #{line_count}"
      
      return batch_file
    rescue => e
      puts "   ❌ Failed to create JSONL file: #{e.message}"
      return nil
    end
  end
  
  def upload_batch_file(file_path)
    puts "📤 Uploading file to OpenAI..."
    
    begin
      file_response = @client.files.upload(
        parameters: {
          file: file_path,
          purpose: "batch"
        }
      )
      
      puts "   ✅ File uploaded successfully"
      puts "   📎 File ID: #{file_response['id']}"
      puts "   📊 Size: #{file_response['bytes']} bytes"
      
      return file_response['id']
    rescue => e
      puts "   ❌ Failed to upload file: #{e.message}"
      return nil
    end
  end
  
  def create_batch_job(file_id)
    puts "🚀 Creating batch job..."
    
    begin
      batch_response = @client.batches.create(
        parameters: {
          input_file_id: file_id,
          endpoint: "/v1/embeddings",
          completion_window: "24h",
          metadata: {
            description: "OK-OFFLINE embeddings test batch",
            created_by: "historical_data_import"
          }
        }
      )
      
      puts "   ✅ Batch job created successfully"
      puts "   🆔 Batch ID: #{batch_response['id']}"
      puts "   📊 Status: #{batch_response['status']}"
      puts "   ⏰ Created: #{Time.at(batch_response['created_at'])}"
      puts "   ⏰ Expires: #{Time.at(batch_response['expires_at'])}"
      
      return batch_response['id']
    rescue => e
      puts "   ❌ Failed to create batch job: #{e.message}"
      return nil
    end
  end
  
  def check_batch_status(batch_id)
    puts "🔍 Checking batch status..."
    
    begin
      batch_status = @client.batches.retrieve(id: batch_id)
      
      puts "   📊 Status: #{batch_status['status']}"
      puts "   📈 Progress: #{batch_status['request_counts']['completed']}/#{batch_status['request_counts']['total']}"
      
      case batch_status['status']
      when 'validating'
        puts "   ⏳ Batch is being validated..."
      when 'in_progress'
        puts "   🔄 Batch is processing..."
      when 'completed'
        puts "   ✅ Batch completed!"
        puts "   📁 Output file: #{batch_status['output_file_id']}"
      when 'failed'
        puts "   ❌ Batch failed!"
        puts "   📁 Error file: #{batch_status['error_file_id']}" if batch_status['error_file_id']
      else
        puts "   📊 Status: #{batch_status['status']}"
      end
      
    rescue => e
      puts "   ❌ Failed to check batch status: #{e.message}"
    end
  end
  
  public
  
  def estimate_costs
    items_without_embeddings = SearchableItem.where(embedding: nil).count
    
    # Estimate tokens per item (rough average based on our data)
    avg_chars_per_item = SearchableItem.where.not(searchable_text: nil)
                                       .limit(100)
                                       .average('LENGTH(searchable_text)')&.to_i || 200
    
    # Rough conversion: 1 token ≈ 4 characters for English text
    avg_tokens = (avg_chars_per_item / 4.0).ceil
    
    # Current OpenAI pricing (as of Jan 2025)
    regular_cost_per_1k = 0.00002  # text-embedding-3-small: $0.00002 per 1K tokens
    batch_discount = 0.5           # 50% discount for batch API
    batch_cost_per_1k = regular_cost_per_1k * batch_discount
    
    total_tokens = items_without_embeddings * avg_tokens
    regular_total = (total_tokens / 1000.0) * regular_cost_per_1k
    batch_total = (total_tokens / 1000.0) * batch_cost_per_1k
    savings = regular_total - batch_total
    
    puts "\n💰 Cost Analysis:"
    puts "   Items needing embeddings: #{items_without_embeddings.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts "   Average text length: #{avg_chars_per_item} chars (#{avg_tokens} tokens)"
    puts "   Total tokens: #{total_tokens.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts ""
    puts "   Regular API cost: $#{sprintf('%.4f', regular_total)}"
    puts "   Batch API cost:   $#{sprintf('%.4f', batch_total)}"
    puts "   💸 Savings:       $#{sprintf('%.4f', savings)} (50%)"
    puts ""
    puts "   ⏰ Trade-off: Batch API takes up to 24 hours vs immediate results"
  end
  
  def list_existing_batches
    puts "\n📋 Existing Batch Jobs:"
    
    begin
      batches = @client.batches.list(parameters: { limit: 10 })
      
      if batches['data'].empty?
        puts "   No existing batches found"
        return
      end
      
      batches['data'].each do |batch|
        status_emoji = case batch['status']
                      when 'completed' then '✅'
                      when 'failed' then '❌'
                      when 'in_progress' then '🔄'
                      when 'validating' then '⏳'
                      else '📊'
                      end
        
        puts "   #{status_emoji} #{batch['id']} (#{batch['status']})"
        puts "      Created: #{Time.at(batch['created_at']).strftime('%Y-%m-%d %H:%M')}"
        if batch['request_counts']['total'] > 0
          puts "      Progress: #{batch['request_counts']['completed']}/#{batch['request_counts']['total']}"
        end
        puts "      Endpoint: #{batch['endpoint']}"
        puts ""
      end
      
    rescue => e
      puts "   ❌ Failed to list batches: #{e.message}"
    end
  end
end

# Run the test
if __FILE__ == $0
  tester = BatchApiTester.new
  tester.list_existing_batches
  tester.estimate_costs
  
  puts "\n" + "="*50
  puts "🤔 Would you like to run a test batch? (y/N)"
  
  # For automation, we'll skip the interactive part
  # Uncomment the next lines to run interactively:
  # response = STDIN.gets.chomp.downcase
  # if response == 'y' || response == 'yes'
  #   tester.run_test
  # else
  #   puts "Skipping batch test."
  # end
  
  puts "Run 'ruby lib/tasks/test_batch_api_workflow.rb' and answer 'y' to test the batch API"
end