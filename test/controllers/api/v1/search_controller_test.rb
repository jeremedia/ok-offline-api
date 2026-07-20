require_relative "../../../test_helper"
require "minitest/mock"

class Api::V1::SearchControllerTest < ActionDispatch::IntegrationTest
  test "status works without an LLM key" do
    host! "offline.oknotok.com"
    original = ENV.delete("OPENAI_API_KEY")
    SearchableItem.create!(uid: "status-camp", item_type: "camp", year: 2026, name: "Status Camp", searchable_text: "Status Camp")

    get "/api/v1/search/status", params: { year: 2026 }

    assert_response :success
    body = response.parsed_body
    assert_equal 2026, body["year"]
    assert_equal false, body["vector_service_configured"]
    assert_equal 1, body["total_count"]
  ensure
    ENV["OPENAI_API_KEY"] = original if original
  end

  test "vector search returns a typed 503 without an LLM key" do
    host! "offline.oknotok.com"
    original = ENV.delete("OPENAI_API_KEY")
    post "/api/v1/search/vector", params: { query: "music", year: 2026 }

    assert_response :service_unavailable
    assert_equal "vector_search_unavailable", response.parsed_body.dig("error", "code")
  ensure
    ENV["OPENAI_API_KEY"] = original if original
  end

  test "provider failures return the same typed 503" do
    host! "offline.oknotok.com"
    original = ENV["OPENAI_API_KEY"]
    ENV["OPENAI_API_KEY"] = "test-key"
    provider = Object.new
    provider.define_singleton_method(:generate_embedding) do |_query|
      raise Search::EmbeddingService::ProviderError, "provider unavailable"
    end

    Search::EmbeddingService.stub(:new, provider) do
      post "/api/v1/search/vector", params: { query: "music", year: 2026 }
    end

    assert_response :service_unavailable
    assert_equal "vector_search_unavailable", response.parsed_body.dig("error", "code")
  ensure
    ENV["OPENAI_API_KEY"] = original
  end

  test "hybrid and entity searches work without an LLM key" do
    host! "offline.oknotok.com"
    original = ENV.delete("OPENAI_API_KEY")
    item = SearchableItem.create!(
      uid: "offline-search",
      item_type: "camp",
      year: 2026,
      name: "Music Camp",
      searchable_text: "Music Camp ambient sound"
    )
    item.search_entities.create!(entity_type: "activity", entity_value: "music", confidence: 0.9)

    post "/api/v1/search/hybrid", params: { query: "ambient", year: 2026 }
    assert_response :success
    assert_equal "offline-search", response.parsed_body.dig("results", 0, "uid")
    assert_equal "keyword", response.parsed_body.dig("meta", "search_type")

    post "/api/v1/search/entities", params: { entities: [ "music" ], year: 2026 }
    assert_response :success
    assert_equal "offline-search", response.parsed_body.dig("results", 0, "uid")
  ensure
    ENV["OPENAI_API_KEY"] = original if original
  end
end
