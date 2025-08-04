# frozen_string_literal: true

class RefreshStaleCapsulesJob < ApplicationJob
  queue_as :style_capsule_maintenance
  
  # Run periodically to refresh capsules approaching expiration
  def perform(refresh_window_hours: 24, batch_size: 10)
    Rails.logger.info "RefreshStaleCapsulesJob: Starting refresh check (window: #{refresh_window_hours}h)"
    
    stale_capsules = StyleCapsule.stale(refresh_window_hours)
                                .order(:expires_at)
                                .limit(batch_size)
    
    if stale_capsules.empty?
      Rails.logger.info "RefreshStaleCapsulesJob: No stale capsules found"
      return
    end
    
    Rails.logger.info "RefreshStaleCapsulesJob: Found #{stale_capsules.count} stale capsules to refresh"
    
    refreshed_count = 0
    failed_count = 0
    
    stale_capsules.each do |capsule|
      begin
        # Enqueue refresh job for this capsule
        BuildStyleCapsuleJob.perform_later(
          persona_id: capsule.persona_id,
          persona_label: capsule.persona_label,
          era: capsule.era,
          require_rights: capsule.rights_scope
        )
        
        refreshed_count += 1
        Rails.logger.debug "RefreshStaleCapsulesJob: Enqueued refresh for #{capsule.persona_id}"
        
      rescue => e
        failed_count += 1
        Rails.logger.error "RefreshStaleCapsulesJob: Failed to enqueue refresh for #{capsule.persona_id}: #{e.message}"
      end
    end
    
    Rails.logger.info "RefreshStaleCapsulesJob: Completed - enqueued #{refreshed_count}, failed #{failed_count}"
    
    # Record metrics
    record_refresh_metrics(refreshed_count, failed_count, stale_capsules.count)
    
    # Schedule next run if there are more stale capsules
    if stale_capsules.count == batch_size
      # There might be more stale capsules, schedule another run
      RefreshStaleCapsulesJob.perform_later(
        refresh_window_hours: refresh_window_hours,
        batch_size: batch_size
      )
    end
    
  rescue => e
    Rails.logger.error "RefreshStaleCapsulesJob exception: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    raise e
  end
  
  # Clean up expired capsules (separate maintenance task)
  def self.cleanup_expired_capsules(batch_size: 50)
    Rails.logger.info "Cleaning up expired style capsules"
    
    expired_count = StyleCapsule.where('expires_at < ?', Time.current).count
    
    if expired_count == 0
      Rails.logger.info "No expired capsules to clean up"
      return 0
    end
    
    Rails.logger.info "Found #{expired_count} expired capsules to clean up"
    
    # Delete in batches to avoid long-running transactions
    total_deleted = 0
    
    loop do
      expired_batch = StyleCapsule.where('expires_at < ?', Time.current)
                                 .limit(batch_size)
      
      break if expired_batch.empty?
      
      batch_count = expired_batch.count
      expired_batch.delete_all
      total_deleted += batch_count
      
      Rails.logger.debug "Deleted #{batch_count} expired capsules"
      
      # Break if we deleted fewer than the batch size (no more to delete)
      break if batch_count < batch_size
    end
    
    Rails.logger.info "Cleanup completed: deleted #{total_deleted} expired capsules"
    
    # Record metrics
    # StatsD.gauge('style_capsules.expired_cleaned', total_deleted)
    
    total_deleted
  end
  
  private
  
  def record_refresh_metrics(refreshed_count, failed_count, total_stale)
    Rails.logger.info "StyleCapsule refresh: enqueued=#{refreshed_count}, failed=#{failed_count}, total_stale=#{total_stale}"
    
    # In production, send to StatsD or other metrics service
    # StatsD.gauge('style_capsules.stale_count', total_stale)
    # StatsD.increment('style_capsules.refresh_jobs_enqueued', refreshed_count)
    # StatsD.increment('style_capsules.refresh_failures', failed_count) if failed_count > 0
  end
end