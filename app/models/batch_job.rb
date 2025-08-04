class BatchJob < ApplicationRecord
  # BatchJob - Tracks OpenAI batch processing jobs for entity extraction
  #
  # This model provides a Rails interface for monitoring OpenAI batch jobs.
  # Integrates with webhook automation and background processing.
  #
  # Job Types:
  # - pool_extraction: Seven Pools of Enliteracy entity extraction
  # - entity_extraction: Basic entity extraction (12 types)
  # - embedding_generation: Future embedding batch processing
  #
  # Monitoring Commands:
  #   BatchJob.recent.limit(10)                    # Recent jobs
  #   BatchJob.active                              # Currently processing
  #   batch_job.progress_percentage                # Completion %
  #   service.check_batch_status(batch_id)         # Sync with OpenAI API
  #
  # Manual Processing (if webhook delayed):
  #   service = Search::BatchBasicEntityExtractionService.new
  #   service.process_batch_results(batch_id)
  #
  # Production Entity Extraction Stats:
  # - Test batches: 23 items across 3 batches
  # - Success rate: 100%
  # - Average entities per item: 5-10
  # - Processing time: 2-5 minutes per batch
  
  # Constants
  STATUSES = %w[pending in_progress completed failed cancelled expired].freeze
  JOB_TYPES = %w[pool_extraction entity_extraction embedding_generation].freeze
  
  # Validations
  validates :batch_id, presence: true, uniqueness: true
  validates :job_type, presence: true, inclusion: { in: JOB_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  
  # Scopes
  scope :active, -> { where(status: %w[pending in_progress]) }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(job_type: type) }
  
  # Callbacks
  before_save :calculate_costs, if: :tokens_changed?
  
  # Instance methods
  def update_from_api_response(response)
    # Map any unknown statuses to our known ones
    api_status = response['status']
    self.status = case api_status
                  when 'validating', 'finalizing'
                    'in_progress'  # These are transitional states
                  when 'in_progress'
                    'in_progress'
                  when 'completed'
                    'completed'
                  when 'failed'
                    'failed'
                  when 'cancelled'
                    'cancelled'
                  when 'expired'
                    'expired'
                  else
                    # Default to pending for unknown statuses
                    Rails.logger.warn "Unknown batch status from API: #{api_status}"
                    'pending'
                  end
    
    self.started_at ||= Time.at(response['in_progress_at']) if response['in_progress_at']
    self.completed_at = Time.at(response['completed_at']) if response['completed_at']
    
    if response['request_counts']
      self.total_items = response['request_counts']['total'] || 0
      self.completed_items = response['request_counts']['completed'] || 0
      self.failed_items = response['request_counts']['failed'] || 0
    end
    
    # Store any errors
    if response['errors'].present?
      self.error_message = response['errors'].to_json
    end
    
    # Update metadata (including original status from API)
    self.metadata.merge!({
      'output_file_id' => response['output_file_id'],
      'error_file_id' => response['error_file_id'],
      'endpoint' => response['endpoint'],
      'expires_at' => response['expires_at'],
      'api_status' => api_status  # Store original API status
    }.compact)
    
    save!
  end
  
  def progress_percentage
    return 0 if total_items.zero?
    (completed_items.to_f / total_items * 100).round(1)
  end
  
  def duration
    return nil unless started_at
    end_time = completed_at || Time.current
    end_time - started_at
  end
  
  def duration_in_words
    return nil unless duration
    
    seconds = duration.to_i
    if seconds < 60
      "#{seconds} seconds"
    elsif seconds < 3600
      "#{(seconds / 60).round} minutes"
    else
      "#{(seconds / 3600.0).round(1)} hours"
    end
  end
  
  def cost_per_item
    return 0 if total_items.zero? || total_cost.nil?
    total_cost / total_items
  end
  
  def estimated_completion_time
    return nil unless in_progress? && completed_items > 0 && started_at
    
    elapsed = Time.current - started_at
    rate = completed_items / elapsed.to_f
    remaining = total_items - completed_items
    
    started_at + (total_items / rate).seconds
  end
  
  def in_progress?
    status == 'in_progress'
  end
  
  def completed?
    status == 'completed'
  end
  
  def failed?
    status == 'failed'
  end
  
  def can_retry?
    failed? || status == 'cancelled'
  end
  
  # Class methods
  def self.create_from_submission(batch_id, job_type, items, estimated_cost = nil)
    create!(
      batch_id: batch_id,
      job_type: job_type,
      status: 'pending',
      total_items: items.count,
      estimated_cost: estimated_cost,
      metadata: {
        'item_ids' => items.pluck(:id),
        'submitted_at' => Time.current
      }
    )
  end
  
  private
  
  def calculate_costs
    return unless input_tokens && output_tokens
    
    # GPT-4.1-nano pricing: $0.20 per 1M tokens
    cost_per_million = 0.20
    
    input_cost = (input_tokens / 1_000_000.0) * cost_per_million
    output_cost = (output_tokens / 1_000_000.0) * cost_per_million
    
    self.total_cost = input_cost + output_cost
  end
  
  def tokens_changed?
    input_tokens_changed? || output_tokens_changed?
  end
end
