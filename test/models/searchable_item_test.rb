require_relative "../test_helper"

class SearchableItemTest < ActiveSupport::TestCase
  test "public placement text is searchable only when present in sanitized metadata" do
    item = SearchableItem.new(
      uid: "camp-2026", item_type: "camp", year: 2026, name: "Example Camp",
      metadata: { "hometown" => "Reno", "location_string" => "3:30 & A" }
    )
    item.prepare_searchable_text
    assert_includes item.searchable_text, "3:30 & A"

    item.metadata.delete("location_string")
    item.prepare_searchable_text
    assert_not_includes item.searchable_text, "3:30 & A"
  end
end
