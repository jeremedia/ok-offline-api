require_relative "../test_helper"
require "digest"
require "fileutils"
require "tmpdir"

class Search::DataImportServiceTest < ActiveSupport::TestCase
  setup do
    @original_data_root = Rails.application.config.x.ok_offline_data_root
    @data_root = Pathname.new(Dir.mktmpdir("ok-offline-snapshot"))
    Rails.application.config.x.ok_offline_data_root = @data_root
    write_snapshot(initial_records)
  end

  teardown do
    Rails.application.config.x.ok_offline_data_root = @original_data_root
    FileUtils.remove_entry(@data_root) if @data_root.exist?
  end

  test "metadata sync is authoritative, idempotent, and preserves unchanged embeddings" do
    first = Search::DataImportService.new(year: 2026).sync_metadata!
    assert_equal 3, first[:total]
    assert_equal 3, SearchableItem.by_year(2026).count

    camp = SearchableItem.find_by!(uid: "camp-1")
    art = SearchableItem.find_by!(uid: "art-1")
    vector = Array.new(1536, 0.001)
    extracted_at = Time.current.change(usec: 0)
    camp.update!(embedding: vector, entity_extracted_at: extracted_at)
    camp.search_entities.create!(entity_type: "theme", entity_value: "test", confidence: 0.9)
    art.update!(embedding: vector, entity_extracted_at: extracted_at)

    changed = initial_records
    changed[:camps][0]["description"] = "Changed searchable text"
    changed[:camps][0]["location_string"] = "3:30 & A"
    changed[:events] = [ event_record("event-2") ]
    write_snapshot(changed, phase: "camp-public")

    second = Search::DataImportService.new(year: 2026).sync_metadata!
    assert_equal 1, second[:removed]
    assert_nil SearchableItem.find_by(uid: "event-1")
    assert SearchableItem.exists?(uid: "event-2")

    camp.reload
    art.reload
    assert_nil camp.embedding
    assert_nil camp.entity_extracted_at
    assert_empty camp.search_entities
    assert_includes camp.searchable_text, "3:30 & A"
    assert_not_nil art.embedding
    assert_equal extracted_at, art.entity_extracted_at.change(usec: 0)

    Search::DataImportService.new(year: 2026).sync_metadata!
    assert_not_nil art.reload.embedding
    assert_equal extracted_at, art.entity_extracted_at.change(usec: 0)
  end

  test "empty structured extraction is marked complete and not repeated" do
    Search::DataImportService.new(year: 2026).sync_metadata!
    calls = 0
    entity_service = Object.new
    entity_service.define_singleton_method(:extract_entities) do |_text, _type|
      calls += 1
      []
    end
    service = Search::DataImportService.new(year: 2026, entity_service: entity_service)

    assert_equal 3, service.extract_entities![:total]
    assert_equal 3, calls
    assert SearchableItem.by_year(2026).where(entity_extracted_at: nil).none?
    assert_equal 0, service.extract_entities![:total]
    assert_equal 3, calls
  end

  private

  def initial_records
    {
      camps: [ { "uid" => "camp-1", "name" => "Camp One", "description" => "Original", "year" => 2026 } ],
      art: [ { "uid" => "art-1", "name" => "Art One", "description" => "Sculpture", "year" => 2026 } ],
      events: [ event_record("event-1") ]
    }
  end

  def event_record(uid)
    { "uid" => uid, "title" => "Event #{uid}", "description" => "Gathering", "year" => 2026, "occurrence_set" => [] }
  end

  def write_snapshot(records, phase: "content-public")
    directory = @data_root.join("2026")
    FileUtils.mkdir_p(directory)
    hashes = {}
    { "camps.json" => records[:camps], "art.json" => records[:art], "events.json" => records[:events] }.each do |file, value|
      content = "#{JSON.pretty_generate(value)}\n"
      directory.join(file).write(content)
      hashes[file] = Digest::SHA256.hexdigest(content)
    end
    metadata = {
      "year" => "2026",
      "phase" => phase,
      "publishedCounts" => { "camps" => records[:camps].length, "art" => records[:art].length, "events" => records[:events].length },
      "hashes" => hashes
    }
    directory.join("metadata.json").write("#{JSON.pretty_generate(metadata)}\n")
  end
end
