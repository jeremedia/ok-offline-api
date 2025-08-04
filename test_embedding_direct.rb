#!/usr/bin/env ruby
require_relative 'config/environment'

puts "Testing embedding service directly..."
puts "=" * 60

service = Search::EmbeddingService.new
begin
  embedding = service.generate_embedding("2017 temple burning man")
  if embedding
    puts "Success! Generated embedding with #{embedding.length} dimensions"
    puts "First 10 values: #{embedding.first(10).map { |v| v.round(4) }}"
  else
    puts "Embedding generation returned nil"
  end
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end