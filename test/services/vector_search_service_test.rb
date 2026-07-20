require_relative "../test_helper"

class Search::VectorSearchServiceTest < ActiveSupport::TestCase
  setup do
    @query_vector = Array.new(1_536, 0.0)
    @query_vector[0] = 1.0
    @embedding_service = Object.new
    query_vector = @query_vector
    @embedding_service.define_singleton_method(:generate_embedding) { |_query| query_vector }

    close_vector = Array.new(1_536, 0.0)
    close_vector[0] = 1.0
    far_vector = Array.new(1_536, 0.0)
    far_vector[1] = 1.0

    SearchableItem.create!(
      uid: "close-2026", item_type: "camp", year: 2026, name: "Exact Music Camp",
      searchable_text: "Exact Music Camp", embedding: close_vector
    )
    SearchableItem.create!(
      uid: "far-2026", item_type: "camp", year: 2026, name: "Other Camp",
      searchable_text: "Other Camp", embedding: far_vector
    )
    SearchableItem.create!(
      uid: "close-2025", item_type: "camp", year: 2025, name: "Historical Music Camp",
      searchable_text: "Historical Music Camp", embedding: close_vector
    )
  end

  test "vector search enforces year and similarity threshold" do
    result = Search::VectorSearchService.new(embedding_service: @embedding_service).search(
      query: "music", year: 2026, limit: 5, threshold: 0.9
    )

    assert_equal "vector", result[:search_type]
    assert_equal [ "close-2026" ], result[:results].pluck(:uid)
    assert_equal [ 2026 ], result[:results].pluck(:year).uniq
  end

  test "hybrid responses identify themselves and include the year" do
    result = Search::VectorSearchService.new(embedding_service: @embedding_service).hybrid_search(
      query: "Exact Music Camp", year: 2026, limit: 5
    )

    assert_equal "hybrid", result[:search_type]
    assert result[:results].any? { |item| item[:uid] == "close-2026" }
    assert_equal [ 2026 ], result[:results].pluck(:year).uniq
  end
end
