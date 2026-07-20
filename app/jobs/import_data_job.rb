class ImportDataJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  def perform(run_id)
    run = SeasonImportRun.find(run_id)
    run.start!
    service = Search::DataImportService.new(
      year: run.year,
      progress: ->(**progress) { run.progress!(**progress) }
    )

    run.stages.each do |stage|
      case stage
      when "metadata" then service.sync_metadata!
      when "embeddings" then service.generate_embeddings!
      when "entities" then service.extract_entities!
      end
    end
    run.complete!
  rescue StandardError => error
    run&.fail!(error)
    raise
  end
end
