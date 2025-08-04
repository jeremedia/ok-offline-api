namespace :webhooks do
  desc "Show webhook configuration and test endpoint"
  task debug: :environment do
    puts "🔧 Webhook Configuration"
    puts "=" * 60
    
    puts "\n📋 Environment Variables:"
    puts "  OPENAI_WEBHOOK_SECRET: #{ENV['OPENAI_WEBHOOK_SECRET'].present? ? '✅ Set' : '❌ Not set'}"
    
    puts "\n🌐 Webhook Endpoint:"
    puts "  URL: https://your-domain.com/api/v1/webhooks/openai_batch"
    puts "  Method: POST"
    puts "  Content-Type: application/json"
    
    puts "\n🔐 Expected Headers (Standard Webhooks spec):"
    puts "  webhook-id: wh_..."
    puts "  webhook-timestamp: 1234567890"
    puts "  webhook-signature: v1,base64signature"
    puts "  content-type: application/json"
    
    puts "\n📝 To set webhook secret:"
    puts "  1. Get secret from OpenAI dashboard"
    puts "  2. Add to .env: OPENAI_WEBHOOK_SECRET=whsec_..."
    puts "  3. Restart Rails server"
    
    puts "\n🧪 Test with curl:"
    puts <<~CURL
      curl -X POST https://your-domain.com/api/v1/webhooks/openai_batch \\
        -H "Content-Type: application/json" \\
        -d '{
          "id": "evt_test",
          "object": "event",
          "created_at": #{Time.now.to_i},
          "type": "batch.completed",
          "data": {"id": "batch_test123"}
        }'
    CURL
  end
  
  desc "Log all headers from last webhook request"
  task :headers, [:batch_id] => :environment do |t, args|
    # This would need to be implemented with request logging
    puts "To debug headers, add this to your webhook controller:"
    puts <<~CODE
      Rails.logger.info "=== Webhook Headers ==="
      request.headers.each do |key, value|
        if key.start_with?('HTTP_') || key.include?('CONTENT')
          Rails.logger.info "  \#{key}: \#{value}"
        end
      end
      Rails.logger.info "======================"
    CODE
  end
end