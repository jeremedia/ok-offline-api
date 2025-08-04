#!/usr/bin/env ruby
require_relative '../../config/environment'

# Test the Batch Embedding Service with a small subset
class BatchEmbeddingTester
  def initialize
    @batch_service = Search::BatchEmbeddingService.new
  end
  
  def run_test
    puts "🧪 Testing Batch Embedding API"
    puts "=" * 50
    
    # Get a small sample of items without embeddings
    test_items = SearchableItem.where(embedding: nil).limit(5)
    
    if test_items.empty?
      puts "❌ No items without embeddings found for testing"
      return
    end
    
    puts "📋 Test Items:"
    test_items.each_with_index do |item, i|
      puts "   #{i+1}. #{item.name} (#{item.item_type}, #{item.year})"
      puts "      Text: #{item.searchable_text[0..100]}..."
    end
    
    puts "\n🚀 Testing immediate batch processing..."
    test_immediate_batch(test_items)
    
    puts "\n🔄 Testing async batch job creation..."
    test_batch_job_creation(test_items.limit(3))
  end
  
  private
  
  def test_immediate_batch(items)
    # Test the immediate batch processing (more expensive but faster)
    puts "Processing #{items.count} items with immediate batch..."
    
    start_time = Time.current
    
    begin
      @batch_service.send(:process_batch, items)
      
      duration = Time.current - start_time
      puts "✅ Immediate batch completed in #{duration.round(2)}s"
      
      # Check if embeddings were generated
      items.reload
      embedded_count = items.count { |item| item.embedding.present? }
      puts "   Embeddings generated: #{embedded_count}/#{items.count}"
      
      if embedded_count == items.count
        puts "✅ All embeddings generated successfully!"
      else
        puts "⚠️  Some embeddings failed to generate"
      end
      
    rescue => e
      puts "❌ Immediate batch failed: #{e.message}"
      puts "   This might be due to missing OPENAI_API_KEY"
    end
  end
  
  def test_batch_job_creation(items)
    # Test the async batch job creation (cheaper but takes 24h)
    puts "Creating batch job for #{items.count} items..."
    
    begin
      # This would normally create a batch job, but let's just test the JSONL generation
      batch_id = SecureRandom.hex(8)
      batch_file_path = Rails.root.join('tmp', "test_batch_#{batch_id}.jsonl")
      
      # Create JSONL file
      File.open(batch_file_path, 'w') do |file|
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
      
      # Verify JSONL format
      line_count = File.readlines(batch_file_path).count
      puts "✅ JSONL file created with #{line_count} requests"
      
      # Show sample request
      first_line = File.readlines(batch_file_path).first
      request = JSON.parse(first_line)
      puts "   Sample request:"
      puts "     custom_id: #{request['custom_id']}"
      puts "     model: #{request['body']['model']}"
      puts "     input_length: #{request['body']['input'].length} chars"
      
      # Clean up
      File.delete(batch_file_path)
      puts "✅ JSONL format validation passed"
      
    rescue => e
      puts "❌ Batch job creation test failed: #{e.message}"
    end
  end
  
  public
  
  def estimate_costs
    total_items = SearchableItem.where(embedding: nil).count
    avg_tokens = 100 # rough estimate
    
    # Current pricing (as of 2024)
    regular_cost_per_1k = 0.00002  # $0.00002 per 1K tokens
    batch_cost_per_1k = 0.00001    # 50% discount
    
    regular_total = (total_items * avg_tokens / 1000.0) * regular_cost_per_1k
    batch_total = (total_items * avg_tokens / 1000.0) * batch_cost_per_1k
    savings = regular_total - batch_total
    
    puts "\n💰 Cost Estimation:"
    puts "   Items needing embeddings: #{total_items}"
    puts "   Estimated tokens per item: #{avg_tokens}"
    puts "   Regular API cost: $#{regular_total.round(4)}"
    puts "   Batch API cost: $#{batch_total.round(4)}"
    puts "   Savings: $#{savings.round(4)} (#{((savings/regular_total)*100).round(1)}%)"
  end
end

# Run the test
if __FILE__ == $0
  tester = BatchEmbeddingTester.new
  tester.run_test
  tester.estimate_costs
end