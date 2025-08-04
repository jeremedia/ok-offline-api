#!/usr/bin/env ruby
require_relative '../../config/environment'
require 'net/http'
require 'json'

# Test the webhook endpoint locally
class WebhookEndpointTester
  def initialize
    @webhook_secret = ENV['OPENAI_WEBHOOK_SECRET']
    @webhook_url = 'http://localhost:3555/api/v1/webhooks/openai_batch'
  end
  
  def test_webhook_endpoint
    puts "🔗 Testing Webhook Endpoint"
    puts "=" * 40
    
    # Check if webhook secret is loaded
    if @webhook_secret
      puts "✅ Webhook secret loaded: #{@webhook_secret[0..20]}..."
    else
      puts "❌ OPENAI_WEBHOOK_SECRET not found in environment"
      return false
    end
    
    # Check if Rails server is running
    puts "\n🔍 Checking if Rails server is running on port 3555..."
    
    begin
      uri = URI('http://localhost:3555/up')
      response = Net::HTTP.get_response(uri)
      
      if response.code == '200'
        puts "✅ Rails server is running"
      else
        puts "⚠️  Rails server response: #{response.code}"
      end
    rescue => e
      puts "❌ Rails server not accessible: #{e.message}"
      puts "   Start server with: rails server -b 0.0.0.0 -p 3555"
      return false
    end
    
    # Test webhook route exists
    puts "\n🛣️  Testing webhook route..."
    
    begin
      uri = URI(@webhook_url)
      http = Net::HTTP.new(uri.host, uri.port)
      
      # Create a mock webhook payload (similar to what OpenAI sends)
      mock_payload = {
        object: "event",
        id: "evt_test123",
        type: "batch.completed",
        created_at: Time.current.to_i,
        data: { id: "batch_test123" }
      }.to_json
      
      # For a real test, we'd need to generate proper webhook signatures
      # For now, just test that the route exists
      request = Net::HTTP::Post.new(uri.path)
      request['Content-Type'] = 'application/json'
      request['webhook-id'] = 'wh_test123'
      request['webhook-timestamp'] = Time.current.to_i.to_s
      request['webhook-signature'] = 'v1,test_signature'
      request.body = mock_payload
      
      response = http.request(request)
      
      case response.code
      when '200'
        puts "✅ Webhook endpoint responded successfully"
      when '400'
        puts "⚠️  Webhook endpoint returned 400 (expected - signature verification failed)"
        puts "   This is normal for a test request without proper signature"
      else
        puts "📊 Webhook endpoint response: #{response.code}"
        puts "   Body: #{response.body}"
      end
      
    rescue => e
      puts "❌ Error testing webhook: #{e.message}"
      return false
    end
    
    return true
  end
  
  def show_webhook_info
    puts "\n📋 Webhook Configuration:"
    puts "   Endpoint: #{@webhook_url}"
    puts "   Secret: #{@webhook_secret ? 'Configured ✅' : 'Missing ❌'}"
    puts "   Events: batch.completed, batch.failed, batch.expired"
    
    puts "\n📊 Current Batch Status:"
    begin
      client = OpenAI::Client.new(api_key: ENV['OPENAI_API_KEY'])
      batch = client.batches.retrieve(id: 'batch_688bc8ea82708190b0a8f3b32e5925ae')
      puts "   Status: #{batch['status']}"
      puts "   Progress: #{batch['request_counts']['completed']}/#{batch['request_counts']['total']}"
      
      if batch['status'] == 'completed'
        puts "   🎉 Batch completed! Webhook should have been triggered."
      elsif batch['status'] == 'in_progress'
        puts "   ⏳ Batch still processing..."
      end
    rescue => e
      puts "   ❌ Error checking batch: #{e.message}"
    end
  end
end

# Run the test
if __FILE__ == $0
  tester = WebhookEndpointTester.new
  
  if tester.test_webhook_endpoint
    puts "\n✅ Webhook endpoint test completed"
  else
    puts "\n❌ Webhook endpoint test failed"
  end
  
  tester.show_webhook_info
end