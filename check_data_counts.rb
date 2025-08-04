#!/usr/bin/env ruby
require_relative 'config/environment'

puts "SearchableItems: #{SearchableItem.count}"
puts "SearchEntities: #{SearchEntity.count}"

pool_types = SearchEntity.where("entity_type LIKE 'pool_%'").distinct.pluck(:entity_type).sort
puts "Pool types: #{pool_types.join(', ')}"

pool_types.each do |pool_type|
  count = SearchEntity.where(entity_type: pool_type).count
  puts "  #{pool_type}: #{count} entities"
end