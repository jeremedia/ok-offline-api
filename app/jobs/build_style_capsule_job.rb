# frozen_string_literal: true

class BuildStyleCapsuleJob < ApplicationJob
  queue_as :style_capsule
  
  # Limit concurrent builds to avoid overloading the system
  limits_concurrency to: 3, per: :queue
  
  def perform(persona_id:, persona_label: nil, era: nil, require_rights: 'public')
    # Generate idempotency key to avoid duplicate builds
    idempotency_key = generate_idempotency_key(persona_id, era, require_rights)
    
    # Use Solid Queue job locking to prevent duplicates
    return if job_already_running?(idempotency_key)
    
    Rails.logger.info "BuildStyleCapsuleJob: Building capsule for #{persona_id}"
    
    ActiveSupport::Notifications.instrument('persona.build_capsule', 
      persona_id: persona_id, 
      era: era, 
      require_rights: require_rights
    ) do
      
      result = Persona::StyleCapsuleBuilder.call(
        persona_id: persona_id,
        persona_label: persona_label,
        era: era,
        require_rights: require_rights
      )
      
      if result[:ok]
        Rails.logger.info "BuildStyleCapsuleJob: Successfully built capsule for #{persona_id}"
        record_success_metrics(persona_id, result)
      else
        Rails.logger.error "BuildStyleCapsuleJob: Failed to build capsule for #{persona_id}: #{result[:error]}"
        record_failure_metrics(persona_id, result[:error])
        
        # Re-raise to mark job as failed in Solid Queue
        raise StandardError, "Capsule build failed: #{result[:error]}"
      end
      
      result
    end
  rescue => e
    Rails.logger.error "BuildStyleCapsuleJob exception: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    
    record_failure_metrics(persona_id, e.message)
    raise e
  ensure
    # Clear job lock
    clear_job_lock(idempotency_key)
  end
  
  private
  
  def generate_idempotency_key(persona_id, era, require_rights)
    graph_version = "2025.07"  # Should come from config
    lexicon_version = "2025.07"  # Should come from config
    
    "build_capsule:#{persona_id}:#{era || 'any'}:#{require_rights}:#{graph_version}:#{lexicon_version}"
  end
  
  def job_already_running?(idempotency_key)
    # Use Rails cache to implement simple job locking
    lock_key = "job_lock:#{idempotency_key}"
    
    # Try to acquire lock
    acquired = Rails.cache.write(lock_key, Time.current.to_i, unless_exist: true, expires_in: 30.minutes)
    
    if acquired
      Rails.logger.debug "BuildStyleCapsuleJob: Acquired lock for #{idempotency_key}"
      false  # Not already running, we got the lock
    else
      Rails.logger.info "BuildStyleCapsuleJob: Already running for #{idempotency_key}"
      true   # Already running
    end
  end
  
  def clear_job_lock(idempotency_key)
    lock_key = "job_lock:#{idempotency_key}"
    Rails.cache.delete(lock_key)
    Rails.logger.debug "BuildStyleCapsuleJob: Released lock for #{idempotency_key}"
  end
  
  def record_success_metrics(persona_id, result)
    # Record metrics for monitoring
    execution_time = result.dig(:meta, :execution_time) || 0
    confidence = result[:style_confidence] || 0
    corpus_size = result.dig(:meta, :corpus_size) || 0
    
    Rails.logger.info "StyleCapsule built: persona=#{persona_id}, confidence=#{confidence}, corpus_size=#{corpus_size}, time=#{execution_time}s"
    
    # In production, send to StatsD or other metrics service
    # StatsD.increment('style_capsules.built')
    # StatsD.timing('style_capsules.build_time', execution_time * 1000)
    # StatsD.gauge('style_capsules.confidence', confidence)
    # StatsD.gauge('style_capsules.corpus_size', corpus_size)
  end
  
  def record_failure_metrics(persona_id, error_message)
    Rails.logger.error "StyleCapsule build failed: persona=#{persona_id}, error=#{error_message}"
    
    # In production, send to StatsD or other metrics service
    # StatsD.increment('style_capsules.build_failures')
  end
end