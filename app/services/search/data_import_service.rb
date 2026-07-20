# frozen_string_literal: true

require "digest"

module Search
  class DataImportService
    BATCH_SIZE = 50
    TYPE_FILES = { "camp" => "camps.json", "art" => "art.json", "event" => "events.json" }.freeze

    attr_reader :year, :metadata

    def initialize(year:, progress: ->(*) { }, embedding_service: nil, entity_service: nil)
      @year = year.to_i
      @progress = progress
      @embedding_service = embedding_service
      @entity_service = entity_service
      @data_root = Rails.application.config.x.ok_offline_data_root.join(@year.to_s)
      @metadata = read_json("metadata.json")
      validate_snapshot!
    end

    # Stage 1: authoritative metadata/text synchronization. This stage never
    # constructs an LLM client and is safe to use for status/analytics workflows.
    def sync_metadata!
      expected_uids = []
      total = metadata.fetch("publishedCounts").values.sum
      processed = 0

      TYPE_FILES.each do |item_type, file_name|
        records = read_json(file_name)
        validate_collection!(item_type, records)
        expected_uids.concat(records.map { |record| record.fetch("uid") })

        records.each_slice(BATCH_SIZE) do |batch|
          SearchableItem.transaction do
            batch.each { |record| upsert_record!(record, item_type) }
          end
          processed += batch.length
          report(:metadata, processed, total)
        end
      end

      removed = SearchableItem.by_year(year)
        .where(item_type: TYPE_FILES.keys)
        .where.not(uid: expected_uids)
        .delete_all
      report(:metadata, total, total, removed: removed)
      { total: total, removed: removed }
    end

    # Stage 2: only new/changed searchable text has a nil embedding, so unchanged
    # vectors remain intact and the 1536-dimensional model contract is preserved.
    def generate_embeddings!
      scope = SearchableItem.by_year(year).where(item_type: TYPE_FILES.keys, embedding: nil)
      total = scope.count
      return report(:embeddings, 0, 0) if total.zero?

      service = @embedding_service || EmbeddingService.new
      processed = 0
      scope.find_in_batches(batch_size: BATCH_SIZE) do |items|
        embeddings = service.generate_embeddings_batch(items.map(&:searchable_text))
        raise "Embedding count mismatch: #{embeddings.length}/#{items.length}" unless embeddings.length == items.length

        SearchableItem.transaction do
          items.zip(embeddings).each do |item, embedding|
            raise "Missing embedding for #{item.uid}" unless embedding&.length == 1536
            item.update_columns(embedding: embedding, updated_at: Time.current)
          end
        end
        processed += items.length
        report(:embeddings, processed, total)
      end
      { total: total }
    end

    # Stage 3: entity extraction is independently resumable and only visits
    # records with no entities (new or text-changed records).
    def extract_entities!
      scope = SearchableItem.by_year(year).where(item_type: TYPE_FILES.keys, entity_extracted_at: nil)
      total = scope.count
      return report(:entities, 0, 0) if total.zero?

      service = @entity_service || EntityExtractionService.new
      processed = 0
      scope.find_each do |item|
        entities = service.extract_entities(item.searchable_text, item.item_type)
        SearchEntity.transaction do
          entities.each { |attributes| item.search_entities.create!(attributes) }
          item.update!(entity_extracted_at: Time.current)
        end
        processed += 1
        report(:entities, processed, total) if (processed % 10).zero? || processed == total
      end
      { total: total }
    end

    private

    def validate_snapshot!
      raise "Snapshot year mismatch" unless metadata.fetch("year").to_i == year
      counts = metadata.fetch("publishedCounts")
      raise "Snapshot phase missing" if metadata["phase"].blank?

      TYPE_FILES.each do |type, file_name|
        path = @data_root.join(file_name)
        raise "Missing snapshot file #{path}" unless path.file?
        expected_hash = metadata.fetch("hashes").fetch(file_name)
        actual_hash = Digest::SHA256.file(path).hexdigest
        raise "Snapshot hash mismatch for #{file_name}" unless ActiveSupport::SecurityUtils.secure_compare(expected_hash, actual_hash)
        expected_count = counts.fetch(metadata_count_key(type))
        raise "Invalid published count for #{type}" unless expected_count.to_i.positive?
      end
    end

    def validate_collection!(item_type, records)
      raise "#{item_type} snapshot must be an array" unless records.is_a?(Array)
      expected_key = metadata_count_key(item_type)
      expected_count = metadata.fetch("publishedCounts").fetch(expected_key)
      raise "#{item_type} count mismatch: #{records.length}/#{expected_count}" unless records.length == expected_count
      uids = records.map { |record| record["uid"] }
      raise "#{item_type} contains a missing or duplicate UID" if uids.any?(&:blank?) || uids.uniq.length != uids.length
      raise "#{item_type} contains a year mismatch" unless records.all? { |record| record["year"].to_i == year }
    end

    def upsert_record!(record, item_type)
      item = SearchableItem.find_or_initialize_by(uid: record.fetch("uid"))
      old_text = item.searchable_text
      item.assign_attributes(
        item_type: item_type,
        year: year,
        name: item_type == "event" ? record["title"] : record["name"],
        description: record["description"],
        metadata: record
      )
      item.prepare_searchable_text
      text_changed = item.new_record? || item.searchable_text != old_text
      item.embedding = nil if text_changed
      item.entity_extracted_at = nil if text_changed
      item.save!
      item.search_entities.delete_all if text_changed && item.search_entities.exists?
      item
    end

    def metadata_count_key(item_type)
      { "camp" => "camps", "art" => "art", "event" => "events" }.fetch(item_type)
    end

    def read_json(file_name)
      JSON.parse(@data_root.join(file_name).read)
    rescue JSON::ParserError => error
      raise "Invalid JSON in #{file_name}: #{error.message}"
    end

    def report(stage, processed, total, extra = {})
      @progress.call(stage: stage.to_s, processed: processed, total: total, **extra)
      { stage: stage, processed: processed, total: total, **extra }
    end
  end
end
