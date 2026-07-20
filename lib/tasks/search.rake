namespace :search do
  desc "Import data for vector search"
  task :import, [ :year ] => :environment do |t, args|
    year = (args[:year] || Rails.application.config.x.current_burn_year).to_i
    if ActiveJob::Base.queue_adapter.is_a?(ActiveJob::QueueAdapters::AsyncAdapter)
      abort "The in-process async adapter cannot survive this task exiting. Use search:run[#{year}] or a persistent queue worker."
    end
    run = SeasonImportRun.enqueue!(year: year)
    puts "Queued import run #{run.id} for #{year}: #{run.stages.join(', ')}"
  end

  desc "Queue one explicit import stage: metadata, embeddings, or entities"
  task :stage, [ :year, :stage ] => :environment do |_task, args|
    year = (args[:year] || Rails.application.config.x.current_burn_year).to_i
    stage = args[:stage].to_s
    abort "stage must be one of #{SeasonImportRun::STAGES.join(', ')}" unless SeasonImportRun::STAGES.include?(stage)
    if ActiveJob::Base.queue_adapter.is_a?(ActiveJob::QueueAdapters::AsyncAdapter)
      abort "The in-process async adapter cannot survive this task exiting. Use search:run[#{year},#{stage}] or a persistent queue worker."
    end
    run = SeasonImportRun.enqueue!(year: year, stages: [ stage ])
    puts "Queued import run #{run.id} for #{year}: #{stage}"
  end

  desc "Run an import in this dedicated process: search:run[year] or search:run[year,stage]"
  task :run, [ :year, :stage ] => :environment do |_task, args|
    year = (args[:year] || Rails.application.config.x.current_burn_year).to_i
    stages = args[:stage].present? ? [ args[:stage].to_s ] : SeasonImportRun::STAGES
    invalid = stages - SeasonImportRun::STAGES
    abort "invalid stages: #{invalid.join(', ')}" if invalid.any?

    run = SeasonImportRun.create!(
      year: year,
      stages: stages,
      metadata: { "execution" => "dedicated-process", "queued_at" => Time.current.iso8601 }
    )
    puts "Running import #{run.id} for #{year}: #{stages.join(', ')}"
    ImportDataJob.perform_now(run.id)
    run.reload
    abort "Import #{run.id} failed: #{run.error_message}" unless run.completed?
    puts "Completed import #{run.id} for #{year}"
  end

  desc "Generate missing embeddings"
  task generate_embeddings: :environment do
    items_without_embeddings = SearchableItem.where(embedding: nil)
    total = items_without_embeddings.count

    puts "Found #{total} items without embeddings"

    if total > 0
      embedding_service = Search::EmbeddingService.new

      items_without_embeddings.find_each.with_index do |item, index|
        print "\rGenerating embedding #{index + 1}/#{total}..."

        item.generate_embedding!(embedding_service)

        # Rate limiting - OpenAI has limits
        sleep 0.1 if (index + 1) % 10 == 0
      end

      puts "\nEmbedding generation completed!"
    end
  end

  desc "Clear all search data"
  task clear: :environment do
    puts "Clearing all search data..."

    SearchQuery.destroy_all
    SearchEntity.destroy_all
    SearchableItem.destroy_all

    puts "Search data cleared!"
  end

  desc "Show search statistics"
  task stats: :environment do
    puts "Search Statistics"
    puts "=================="

    puts "\nItems:"
    puts "  Total: #{SearchableItem.count}"
    puts "  With embeddings: #{SearchableItem.with_embedding.count}"

    puts "\nBy type:"
    SearchableItem.group(:item_type).count.each do |type, count|
      puts "  #{type}: #{count}"
    end

    puts "\nEntities:"
    SearchEntity.group(:entity_type).count.each do |type, count|
      puts "  #{type}: #{count}"
    end

    puts "\nSearch queries:"
    puts "  Total: #{SearchQuery.count}"
    puts "  Successful: #{SearchQuery.successful.count}"
    puts "  Average execution time: #{SearchQuery.average_execution_time&.round(2)}s"

    puts "\nPopular queries:"
    SearchQuery.popular_queries(limit: 5).each do |query, count|
      puts "  '#{query}': #{count} times"
    end
  end
end
