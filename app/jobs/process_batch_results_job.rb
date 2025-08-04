class ProcessBatchResultsJob < ApplicationJob
  # ProcessBatchResultsJob - Automatically processes OpenAI batch results via webhook triggers
  #
  # This job is triggered by WebhooksController when OpenAI sends a batch completion webhook.
  # It handles both pool_extraction and entity_extraction job types by delegating to appropriate services.
  #
  # Workflow:
  # 1. OpenAI completes batch processing
  # 2. OpenAI sends webhook to /api/v1/webhooks/openai_batch
  # 3. WebhooksController validates webhook and queues this job
  # 4. This job processes results using the appropriate service
  # 5. BatchJob record is marked as processed
  #
  # Known Issues:
  # - OpenAI webhooks may be delayed, requiring manual processing
  # - Services must implement process_batch_results(batch_id) method signature
  #
  # Manual Processing:
  #   service = Search::BatchBasicEntityExtractionService.new
  #   service.process_batch_results(batch_id)
  queue_as :default
  
  # Retry failed jobs with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  
  def perform(batch_id)
    Rails.logger.info "🔄 Processing batch results for #{batch_id} in background"
    
    # Find the batch job
    batch_job = BatchJob.find_by(batch_id: batch_id)
    unless batch_job
      Rails.logger.error "BatchJob not found for #{batch_id}"
      return
    end
    
    # Skip if already processed
    if batch_job.metadata['processed'] == true
      Rails.logger.info "Batch #{batch_id} already processed, skipping"
      return
    end
    
    # Process the batch results based on job type
    case batch_job.job_type
    when 'pool_extraction'
      service = Search::BatchPoolEntityExtractionService.new
      success = service.process_batch_results(batch_id)
    when 'entity_extraction'
      service = Search::BatchBasicEntityExtractionService.new
      success = service.process_batch_results(batch_id)
    else
      Rails.logger.error "Unknown job type: #{batch_job.job_type}"
      success = false
    end
    
    if success
      # Mark as processed
      batch_job.metadata['processed'] = true
      batch_job.metadata['processed_at'] = Time.current
      batch_job.save!
      
      Rails.logger.info "✅ Batch #{batch_id} processed successfully"
      
      # Log summary based on job type
      case batch_job.job_type
      when 'pool_extraction'
        pool_types = %w[pool_idea pool_manifest pool_experience pool_relational 
                        pool_evolutionary pool_practical pool_emanation]
        
        pool_types.each do |pool_type|
          count = SearchEntity.where(entity_type: pool_type).count
          Rails.logger.info "  #{pool_type}: #{count} total entities"
        end
      when 'entity_extraction'
        basic_types = %w[location activity theme time person item_type 
                         contact organizational service schedule requirement]
        
        basic_types.each do |entity_type|
          count = SearchEntity.where(entity_type: entity_type).count
          Rails.logger.info "  #{entity_type}: #{count} total entities"
        end
      end
    else
      Rails.logger.error "❌ Failed to process batch #{batch_id}"
      raise "Batch processing failed" # Will trigger retry
    end
  end
end
