module Api
  module V1
    class WebhooksController < ActionController::API
      # Skip CSRF protection for webhook requests (not needed in API mode)
      # skip_before_action :verify_authenticity_token
      
      def openai_batch
        Rails.logger.info "Received OpenAI webhook: #{request.headers['webhook-id']}"
        
        begin
          # Verify webhook signature
          event = verify_webhook_signature
          
          # Handle the event
          case event['type']
          when 'batch.completed'
            handle_batch_completed(event)
          when 'batch.failed'
            handle_batch_failed(event)
          when 'batch.expired'
            handle_batch_expired(event)
          else
            Rails.logger.info "Unhandled webhook event type: #{event['type']}"
          end
          
          render json: { status: 'ok' }, status: :ok
          
        rescue => e
          Rails.logger.error "Webhook processing error: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          render json: { error: 'Webhook processing failed' }, status: :bad_request
        end
      end
      
      private
      
      def verify_webhook_signature
        # OpenAI uses Standard Webhooks specification
        webhook_secret = ENV['OPENAI_WEBHOOK_SECRET']
        
        # Log all relevant headers for debugging
        Rails.logger.info "=== Webhook Headers ==="
        Rails.logger.info "webhook-id: #{request.headers['webhook-id']}"
        Rails.logger.info "webhook-timestamp: #{request.headers['webhook-timestamp']}"
        Rails.logger.info "webhook-signature: #{request.headers['webhook-signature']}"
        Rails.logger.info "======================"
        
        if webhook_secret.present?
          # Get headers according to Standard Webhooks spec
          webhook_id = request.headers['webhook-id']
          webhook_timestamp = request.headers['webhook-timestamp']
          webhook_signature = request.headers['webhook-signature']
          
          if webhook_id.blank? || webhook_timestamp.blank? || webhook_signature.blank?
            Rails.logger.error "Missing required webhook headers"
            raise "Missing required webhook headers"
          end
          
          # Get raw request body
          payload = request.raw_post
          
          # Construct the signed content according to Standard Webhooks spec
          signed_content = "#{webhook_id}.#{webhook_timestamp}.#{payload}"
          
          # The secret should be base64 decoded first
          secret_bytes = Base64.decode64(webhook_secret.sub(/^whsec_/, ''))
          
          # Compute expected signature
          expected_signature = Base64.strict_encode64(
            OpenSSL::HMAC.digest('SHA256', secret_bytes, signed_content)
          )
          
          # Extract provided signatures (format: "v1,signature1 v1,signature2")
          provided_signatures = webhook_signature.split(' ').map do |sig|
            sig.split(',', 2).last
          end
          
          # Verify at least one signature matches
          valid = provided_signatures.any? { |sig| secure_compare(sig, expected_signature) }
          
          unless valid
            Rails.logger.error "Invalid webhook signature"
            Rails.logger.error "Expected: v1,#{expected_signature}"
            Rails.logger.error "Received: #{webhook_signature}"
            raise "Invalid webhook signature"
          end
          
          # Check timestamp to prevent replay attacks (5 minute tolerance)
          current_time = Time.now.to_i
          webhook_time = webhook_timestamp.to_i
          if (current_time - webhook_time).abs > 300
            Rails.logger.error "Webhook timestamp too old or in future"
            raise "Webhook timestamp outside acceptable range"
          end
          
          Rails.logger.info "✅ Webhook signature verified successfully"
        else
          Rails.logger.warn "OPENAI_WEBHOOK_SECRET not set - skipping signature verification"
        end
        
        # Parse and return the event
        event = params.except(:controller, :action, :webhook).to_unsafe_h
        Rails.logger.info "Processing webhook event: #{event['type']} for #{event['data']['id']}"
        
        event
      end
      
      def secure_compare(a, b)
        return false unless a.bytesize == b.bytesize
        
        l = a.unpack("C*")
        r = b.unpack("C*")
        result = 0
        l.zip(r) { |x, y| result |= x ^ y }
        result == 0
      end
      
      def handle_batch_completed(event)
        # Handle OpenAI batch completion webhook
        # Note: Webhooks may be delayed after actual batch completion
        # Always check batch status manually if webhook doesn't arrive
        batch_id = event['data']['id']
        Rails.logger.info "🎉 Batch completed: #{batch_id}"
        
        # Update BatchJob record
        batch_job = BatchJob.find_by(batch_id: batch_id)
        if batch_job
          # Sync with API to get final status using appropriate service
          case batch_job.job_type
          when 'pool_extraction'
            service = Search::BatchPoolEntityExtractionService.new
          when 'entity_extraction'
            service = Search::BatchBasicEntityExtractionService.new
          else
            Rails.logger.error "Unknown job type: #{batch_job.job_type}"
            return
          end
          
          service.check_batch_status(batch_id)
          
          Rails.logger.info "Batch #{batch_id} updated: #{batch_job.reload.status}"
        else
          Rails.logger.warn "BatchJob record not found for #{batch_id}"
        end
        
        # Store completion info
        Rails.cache.write("batch_webhook_#{batch_id}", {
          status: 'completed',
          completed_at: Time.current,
          event_id: event['id']
        }, expires_in: 48.hours)
        
        # Queue background processing
        ProcessBatchResultsJob.perform_later(batch_id)
        Rails.logger.info "📋 Queued batch processing job for #{batch_id}"
      end
      
      def handle_batch_failed(event)
        batch_id = event['data']['id']
        Rails.logger.error "❌ Batch failed: #{batch_id}"
        
        # Store failure info
        Rails.cache.write("batch_webhook_#{batch_id}", {
          status: 'failed',
          failed_at: Time.current,
          event_id: event['id']
        }, expires_in: 48.hours)
        
        # Could send alerts, notifications, etc.
      end
      
      def handle_batch_expired(event)
        batch_id = event['data']['id']
        Rails.logger.warn "⏰ Batch expired: #{batch_id}"
        
        # Store expiration info
        Rails.cache.write("batch_webhook_#{batch_id}", {
          status: 'expired',
          expired_at: Time.current,
          event_id: event['id']
        }, expires_in: 48.hours)
      end
    end
  end
end