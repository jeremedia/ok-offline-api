#!/usr/bin/env ruby
require 'json'
require 'set'

# Analyze field usage across all JSON Archive data
data_dir = File.join(File.dirname(__FILE__), '../../db/data/json_archive')

field_stats = {
  camps: Hash.new(0),
  art: Hash.new(0),
  events: Hash.new(0)
}

sample_values = {
  camps: {},
  art: {},
  events: {}
}

# Analyze each year and type
Dir.glob(File.join(data_dir, '*')).each do |year_dir|
  next unless File.directory?(year_dir)
  year = File.basename(year_dir)
  
  # Camps
  camps_file = File.join(year_dir, 'camps.json')
  if File.exist?(camps_file)
    camps = JSON.parse(File.read(camps_file))
    camps.each do |camp|
      camp.keys.each do |key|
        field_stats[:camps][key] += 1
        # Store sample value if we don't have one yet
        if !sample_values[:camps][key] && camp[key] && !camp[key].to_s.empty?
          sample_values[:camps][key] = camp[key]
        end
      end
    end
  end
  
  # Art
  art_file = File.join(year_dir, 'art.json')
  if File.exist?(art_file)
    art_pieces = JSON.parse(File.read(art_file))
    art_pieces.each do |art|
      art.keys.each do |key|
        field_stats[:art][key] += 1
        if !sample_values[:art][key] && art[key] && !art[key].to_s.empty?
          sample_values[:art][key] = art[key]
        end
      end
    end
  end
  
  # Events
  events_file = File.join(year_dir, 'events.json')
  if File.exist?(events_file)
    events = JSON.parse(File.read(events_file))
    events.each do |event|
      event.keys.each do |key|
        field_stats[:events][key] += 1
        if !sample_values[:events][key] && event[key] && !event[key].to_s.empty?
          sample_values[:events][key] = event[key]
        end
      end
    end
  end
end

# Find common fields across all types
all_fields = {
  camps: Set.new(field_stats[:camps].keys),
  art: Set.new(field_stats[:art].keys),
  events: Set.new(field_stats[:events].keys)
}

common_fields = all_fields[:camps] & all_fields[:art] & all_fields[:events]
partially_common = (all_fields[:camps] & all_fields[:art]) | 
                   (all_fields[:camps] & all_fields[:events]) | 
                   (all_fields[:art] & all_fields[:events])

puts "=== FIELD ANALYSIS REPORT ==="
puts "\n## Common Fields (in all 3 types):"
common_fields.sort.each do |field|
  puts "- #{field}"
  puts "  Camps: #{field_stats[:camps][field]} occurrences"
  puts "  Art: #{field_stats[:art][field]} occurrences"
  puts "  Events: #{field_stats[:events][field]} occurrences"
end

puts "\n## Fields by Type:"
[:camps, :art, :events].each do |type|
  puts "\n### #{type.to_s.capitalize} (#{all_fields[type].size} unique fields):"
  all_fields[type].sort.each do |field|
    count = field_stats[type][field]
    sample = sample_values[type][field]
    sample_str = case sample
                 when Hash, Array
                   " (#{sample.class})"
                 when String
                   sample.length > 50 ? " (String: #{sample[0..47]}...)" : " (String: #{sample})"
                 else
                   " (#{sample.class}: #{sample})"
                 end
    
    puts "- #{field}: #{count} items#{sample_str}"
  end
end

puts "\n## Recommendations:"
puts "1. Common fields that should be database columns:"
common_fields.each do |field|
  if %w[uid name year url hometown description].include?(field)
    puts "   - #{field} (already exists or highly queryable)"
  end
end

puts "\n2. Type-specific fields that might warrant columns:"
puts "   - location_string (camps & art) - used for display"
puts "   - artist (art only) - already added"
puts "   - event_type (events only) - already added"

puts "\n3. Complex objects that should stay in metadata:"
%w[location occurrence_set event_type images].each do |field|
  puts "   - #{field} (nested data structure)"
end