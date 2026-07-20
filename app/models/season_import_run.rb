class SeasonImportRun < ApplicationRecord
  STATUSES = %w[queued running completed failed].freeze
  STAGES = %w[metadata embeddings entities].freeze

  validates :year, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :valid_stages

  def self.enqueue!(year:, stages: STAGES)
    run = create!(year: year, stages: stages, metadata: { "queued_at" => Time.current.iso8601 })
    ImportDataJob.perform_later(run.id)
    run
  end

  def start!
    update!(status: "running", started_at: Time.current, heartbeat_at: Time.current)
  end

  def progress!(stage:, processed:, total:, removed: nil, **details)
    attributes = {
      stage: stage,
      processed: processed,
      total: total,
      heartbeat_at: Time.current,
      metadata: metadata.merge("#{stage}_progress" => details.merge("processed" => processed, "total" => total))
    }
    attributes[:removed] = removed if removed
    update!(attributes)
  end

  def complete!
    update!(status: "completed", processed: total, completed_at: Time.current, heartbeat_at: Time.current)
  end

  def fail!(error)
    update!(status: "failed", error_message: error.message.truncate(2_000), heartbeat_at: Time.current)
  end

  def progress_percentage
    return 100.0 if completed?
    return 0.0 if total.zero?
    (processed.to_f / total * 100).round(2)
  end

  def completed? = status == "completed"

  private

  def valid_stages
    errors.add(:stages, "contains an invalid stage") unless Array(stages).all? { |stage| STAGES.include?(stage) }
  end
end
