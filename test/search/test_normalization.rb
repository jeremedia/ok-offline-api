service = Search::EntityNormalizationService.new

puts '🔍 Testing Entity Normalization:'
puts

# Test some common cases
test_cases = [
  ['activity', 'workshop'],
  ['activity', 'workshops'],
  ['activity', 'Class/Workshop'],
  ['activity', 'music'],
  ['activity', 'Music/Party'],
  ['activity', 'party'],
  ['theme', 'Music'],
  ['theme', 'music'],
  ['location', 'Open Playa'],
  ['location', 'playa']
]

test_cases.each do |type, value|
  normalized = service.normalize_entity(type, value)
  if value != normalized
    puts "#{type}: '#{value}' → '#{normalized}'"
  end
end

puts "\n📊 Analyzing similar entities in activities:"
suggestions = Search::EntityNormalizationService.analyze_entities(
  entity_type: 'activity',
  min_similarity: 0.65
).first(10)

suggestions.each do |suggestion|
  puts "\n'#{suggestion[:canonical]}' (#{suggestion[:count]} occurrences)"
  suggestion[:similar].each do |similar|
    similarity_pct = (similar[:similarity] * 100).round
    puts "  → '#{similar[:value]}' (#{similar[:count]} occurrences, #{similarity_pct}% similar)"
  end
end