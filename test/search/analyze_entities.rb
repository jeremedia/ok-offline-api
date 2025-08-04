# Simple entity analysis
puts "📊 Top Activities with Similar Names:"
puts

# Get top activities
activities = SearchEntity
  .where(entity_type: 'activity')
  .group(:entity_value)
  .order(Arel.sql('COUNT(*) DESC'))
  .limit(30)
  .count

# Group similar activities
grouped = {}

activities.each do |activity, count|
  base = activity.downcase.gsub(/[^a-z0-9]/, '')
  
  # Find a group for this activity
  found_group = false
  grouped.each do |group_key, group_items|
    group_base = group_key.downcase.gsub(/[^a-z0-9]/, '')
    
    # Check if they share significant common parts
    if base.include?(group_base) || group_base.include?(base) ||
       (base.length > 4 && group_base.length > 4 && 
        (base[0..3] == group_base[0..3] || base[-4..-1] == group_base[-4..-1]))
      group_items << { value: activity, count: count }
      found_group = true
      break
    end
  end
  
  # Create new group if not found
  unless found_group
    grouped[activity] = [{ value: activity, count: count }]
  end
end

# Show groups with multiple entries
grouped.select { |_, items| items.length > 1 }.each do |key, items|
  total = items.sum { |i| i[:count] }
  puts "Group: #{key} (Total: #{total})"
  items.sort_by { |i| -i[:count] }.each do |item|
    puts "  - #{item[:value]}: #{item[:count]}"
  end
  puts
end

# Show proposed normalization impact
service = Search::EntityNormalizationService.new
normalized_counts = Hash.new(0)

activities.each do |activity, count|
  normalized = service.normalize_entity('activity', activity)
  normalized_counts[normalized] += count
end

puts "\n🔧 After Normalization:"
normalized_counts.sort_by { |_, count| -count }.first(10).each do |activity, count|
  puts "  #{activity}: #{count}"
end