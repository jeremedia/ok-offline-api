module Search
  class EntitySearchService
    def search(entities:, year:, item_types: nil, limit: 20)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      matches = SearchEntity.joins(:searchable_item)
        .where(entity_value: entities)
        .where(searchable_items: { year: year })
      matches = matches.where(searchable_items: { item_type: item_types }) if item_types.present?

      item_ids = matches.group("searchable_items.id")
        .order(Arel.sql("COUNT(search_entities.id) DESC"))
        .limit(limit)
        .pluck("searchable_items.id")
      items = SearchableItem.where(id: item_ids).includes(:search_entities)
      execution_time = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1_000

      {
        results: items.map { |item| format_item(item) },
        total_count: items.length,
        execution_time: execution_time.round(2),
        search_type: "entity"
      }
    end

    private

    def format_item(item)
      {
        uid: item.uid,
        name: item.name,
        type: item.item_type,
        year: item.year,
        description: item.description,
        metadata: item.metadata,
        entities: item.search_entities.pluck(:entity_type, :entity_value)
      }
    end
  end
end
