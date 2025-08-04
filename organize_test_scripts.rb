#!/usr/bin/env ruby
require 'fileutils'

puts "🗂️  Organizing Test Scripts"
puts "=" * 60

# Create directories for organization
test_dirs = {
  'test/batch_processing' => 'Batch API and pool extraction tests',
  'test/search' => 'Search and entity extraction tests',
  'test/weather' => 'Weather API tests',
  'test/visual' => 'OpenGraph and visual generation tests',
  'test/utilities' => 'Utility and debugging scripts'
}

test_dirs.each do |dir, description|
  FileUtils.mkdir_p(dir)
  puts "\n📁 #{dir}/"
  puts "   #{description}"
end

# Categorize and move files
file_mappings = {
  # Batch processing tests
  'test_100_items_batch.rb' => 'test/batch_processing/',
  'test_automated_batch.rb' => 'test/batch_processing/',
  'test_single_item_batch.rb' => 'test/batch_processing/',
  'test_batch_pool_extraction.rb' => 'test/batch_processing/',
  'verify_automation.rb' => 'test/batch_processing/',
  'check_batch_details.rb' => 'test/batch_processing/',
  'check_batch_results.rb' => 'test/batch_processing/',
  'debug_batch_status.rb' => 'test/batch_processing/',
  'debug_single_batch.rb' => 'test/batch_processing/',
  'test_cost_estimation.rb' => 'test/batch_processing/',
  'cost_comparison.rb' => 'test/batch_processing/',
  'process_all_entities_batch.rb' => 'test/batch_processing/',
  'monitor_batch.sh' => 'test/batch_processing/',
  'monitor_batch_4.sh' => 'test/batch_processing/',
  
  # Pool extraction tests
  'test_pool_extraction.rb' => 'test/search/',
  'test_pool_extraction_diverse.rb' => 'test/search/',
  'debug_pool_extraction.rb' => 'test/search/',
  'test_entity_extraction_with_content.rb' => 'test/search/',
  'verify_single_item_entities.rb' => 'test/search/',
  'test_search.rb' => 'test/search/',
  'test_search2.rb' => 'test/search/',
  'test_normalization.rb' => 'test/search/',
  'analyze_entities.rb' => 'test/search/',
  
  # Weather tests
  'test_weather.rb' => 'test/weather/',
  'test_apple_weather.rb' => 'test/weather/',
  'weather_api_examples.sh' => 'test/weather/',
  
  # Visual/OpenGraph tests
  'test_opengraph.rb' => 'test/visual/',
  'test_himg_basic.rb' => 'test/visual/',
  'test_himg_debug.rb' => 'test/visual/',
  'test_himg_with_assets.rb' => 'test/visual/',
  'test_bg_layers.rb' => 'test/visual/',
  'test_bg_simple.rb' => 'test/visual/',
  'test_bg_layers.png' => 'test/visual/',
  'test_bg_only.png' => 'test/visual/',
  'test_debug_1.png' => 'test/visual/',
  'test_debug_2.png' => 'test/visual/',
  'test_output.png' => 'test/visual/',
  
  # Utilities
  'test_solid_queue.rb' => 'test/utilities/',
  'create_batch_pool_extraction_service.rb' => 'test/utilities/',
  'process_batch_smart.rb' => 'test/utilities/'
}

puts "\n\n📋 Files to organize:"
file_mappings.each do |file, destination|
  if File.exist?(file)
    puts "  ✓ #{file} → #{destination}"
  else
    puts "  ✗ #{file} (not found)"
    file_mappings.delete(file)
  end
end

puts "\n❓ This will move #{file_mappings.size} files. Continue? (y/n)"
response = gets.chomp.downcase

if response == 'y'
  puts "\n🚀 Moving files..."
  
  file_mappings.each do |file, destination|
    begin
      FileUtils.mv(file, destination)
      puts "  ✓ Moved #{file}"
    rescue => e
      puts "  ✗ Error moving #{file}: #{e.message}"
    end
  end
  
  puts "\n📝 Creating test documentation..."
  
  # Create README for test directory
  File.write('test/README.md', <<~README)
    # OK-OFFLINE API Test Scripts
    
    This directory contains various test and utility scripts for the OK-OFFLINE API.
    
    ## Directory Structure
    
    ### batch_processing/
    Scripts for testing OpenAI Batch API integration, pool entity extraction, and cost tracking.
    
    ### search/
    Scripts for testing search functionality, entity extraction, and normalization.
    
    ### weather/
    Scripts for testing weather API integrations (Apple Weather, OpenWeatherMap).
    
    ### visual/
    Scripts for testing OpenGraph image generation and visual components.
    
    ### utilities/
    General utility and debugging scripts.
    
    ## Running Tests
    
    Most scripts can be run directly:
    ```bash
    ruby test/batch_processing/test_100_items_batch.rb
    ```
    
    Or use rails runner:
    ```bash
    rails runner test/search/test_pool_extraction.rb
    ```
    
    ## Key Test Scripts
    
    - `batch_processing/verify_automation.rb` - Verifies the full automated batch pipeline
    - `batch_processing/test_100_items_batch.rb` - Tests larger batch processing
    - `search/test_pool_extraction_diverse.rb` - Tests pool extraction across item types
    - `utilities/test_solid_queue.rb` - Tests background job processing
  README
  
  puts "  ✓ Created test/README.md"
  
  puts "\n✅ Organization complete!"
  puts "\n💡 Consider adding these to .gitignore:"
  puts "   test/visual/*.png"
  puts "   test/batch_processing/monitor_batch_*.sh"
else
  puts "\n❌ Organization cancelled"
end