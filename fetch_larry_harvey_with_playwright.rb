#!/usr/bin/env ruby
require_relative 'config/environment'
require 'fileutils'

# Fetch Larry Harvey content using Playwright MCP for better extraction
# Usage: ruby fetch_larry_harvey_with_playwright.rb

URLS_FILE = 'larry_harvey_urls.txt'
OUTPUT_DIR = 'larry_harvey_writings'

# Enhanced URL to metadata mapping
URL_MAPPINGS = {
  'introduction-the-philosophical-center' => {
    filename: 'philosophical_center_introduction_2013.txt',
    title: 'Introduction: The Philosophical Center',
    year: 2013,
    type: 'philosophical_text',
    priority: 1
  },
  'commerce-community-distilling-philosophy' => {
    filename: 'commerce_community_2013.txt', 
    title: 'Commerce & Community: Distilling philosophy from a cup of coffee',
    year: 2013,
    type: 'philosophical_text',
    priority: 1
  },
  'how-the-west-was-won' => {
    filename: 'how_west_was_won_2013.txt',
    title: 'How the West Was Won: Anarchy vs. Civic Responsibility', 
    year: 2013,
    type: 'essay',
    priority: 1
  },
  '10-principles' => {
    filename: 'ten_principles_2004.txt',
    title: 'The Ten Principles of Burning Man',
    year: 2004, 
    type: 'philosophical_text',
    priority: 1
  },
  'a-guide-to-gifting' => {
    filename: 'guide_to_gifting_2019.txt',
    title: 'A Guide to Gifting, Givers and Gratitude',
    year: 2019,
    type: 'philosophical_text',
    priority: 1
  },
  'consensus-collaboration-hierarchy' => {
    filename: 'consensus_collaboration_2014.txt',
    title: 'Consensus, Collaboration, Hierarchy, Authority and Power',
    year: 2014,
    type: 'philosophical_text',
    priority: 2
  },
  'equality-inequity-iniquity' => {
    filename: 'equality_inequity_2014.txt',
    title: 'Equality, Inequity, Iniquity: Concierge Culture',
    year: 2014,
    type: 'essay',
    priority: 2
  },
  'radical-ritual-spirit-and-soul' => {
    filename: 'radical_ritual_spirit_2017.txt',
    title: 'Radical Ritual: Spirit and Soul',
    year: 2017,
    type: 'philosophical_text',
    priority: 2
  },
  'wheel-of-time' => {
    filename: 'theme_wheel_of_time_1999.txt',
    title: '1999 Art Theme: Wheel of Time',
    year: 1999,
    type: 'theme_essay',
    priority: 3
  },
  '03_theme' => {
    filename: 'theme_beyond_belief_2003.txt',
    title: '2003 Art Theme: Beyond Belief',
    year: 2003,
    type: 'theme_essay',
    priority: 3
  },
  'la-vie-boheme' => {
    filename: 'la_vie_boheme_2000.txt',
    title: 'La Vie Boheme: A History of Burning Man',
    year: 2000,
    type: 'speech',
    priority: 2
  },
  'viva' => {
    filename: 'viva_las_xmas_2002.txt',
    title: 'Viva Las Xmas',
    year: 2002,
    type: 'speech',
    priority: 2
  }
}

def fetch_with_playwright(url)
  puts "🎭 Fetching with Playwright: #{url}"
  
  begin
    # Navigate using the MCP Playwright service
    navigate_params = {
      url: url,
      timeout: 30000,
      waitUntil: 'networkidle'
    }
    
    # This calls the actual MCP Playwright navigate function
    nav_result = `cd /Users/jeremy/ok-offline-ecosystem/api && curl -X POST http://localhost:3555/api/v1/mcp/tools -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"playwright_navigate","arguments":#{navigate_params.to_json}},"id":1}'`
    
    # Wait for content to load
    sleep(3)
    
    # Get visible text
    text_params = {}
    text_result = `cd /Users/jeremy/ok-offline-ecosystem/api && curl -X POST http://localhost:3555/api/v1/mcp/tools -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"playwright_get_visible_text","arguments":#{text_params.to_json}},"id":2}'`
    
    # Parse the JSON response to extract text
    begin
      parsed = JSON.parse(text_result)
      if parsed.dig('result', 'content', 0, 'text')
        content_json = JSON.parse(parsed['result']['content'][0]['text'])
        if content_json['text']
          puts "  ✓ Extracted #{content_json['text'].length} characters"
          return content_json['text']
        end
      end
    rescue JSON::ParserError
      puts "  ❌ Failed to parse Playwright response"
    end
    
    puts "  ❌ No text content extracted"
    return nil
    
  rescue => e
    puts "  ❌ Playwright error: #{e.message}"
    return nil
  end
end

def clean_content(raw_content, url)
  return nil unless raw_content && raw_content.length > 100
  
  content = raw_content.dup
  
  # Remove common navigation and footer elements
  noise_patterns = [
    /Skip to main content.*?(?=\w)/i,
    /Navigation.*?(?=\w)/i,
    /Footer.*?(?=\w)/i,
    /Subscribe.*?(?=\w)/i,
    /Share this.*?(?=\w)/i,
    /Related articles.*?(?=\w)/i,
    /Comments.*?(?=\w)/i,
    /Tags:.*?(?=\w)/i,
    /← Previous.*?(?=\w)/i,
    /Next →.*?(?=\w)/i
  ]
  
  noise_patterns.each do |pattern|
    content.gsub!(pattern, '')
  end
  
  # Clean up whitespace
  content = content.strip
                   .gsub(/\n\s*\n\s*\n+/, "\n\n")  # Multiple line breaks to double
                   .gsub(/[ \t]+/, ' ')              # Multiple spaces to single
                   .gsub(/\n /, "\n")                # Remove leading spaces on lines
  
  # Extract main content (look for article start)
  if content.match(/(?:abstract|introduction|overview|summary|essay|article|speech|principles)/i)
    start_pos = content.index($&)
    content = content[start_pos..-1] if start_pos && start_pos > 100
  end
  
  # Minimum content length check
  return nil if content.length < 200
  
  content
end

def determine_metadata(url)
  # Try to find mapping first
  mapping = URL_MAPPINGS.find { |key, _| url.include?(key) }&.last
  return mapping.merge(url: url) if mapping
  
  # Extract year from URL
  year_match = url.match(/(\d{4})/)
  year = year_match ? year_match[1].to_i : 2024
  
  # Determine type from URL patterns
  type = case url
         when /theme/i then 'theme_essay'
         when /speech/i then 'speech'
         when /principle/i then 'philosophical_text'
         when /journal/i then 'essay'
         else 'essay'
         end
  
  # Generate filename from URL
  filename_parts = url.split('/').last(2).join('_')
  filename = filename_parts.gsub(/[^a-z0-9\-_]/, '_').downcase + '.txt'
  
  {
    filename: filename,
    title: filename.gsub(/[_-]/, ' ').gsub('.txt', '').titleize,
    year: year,
    type: type,
    url: url,
    priority: 3
  }
end

def create_text_file(content, metadata, output_dir)
  return unless content && content.length > 200
  
  filepath = File.join(output_dir, metadata[:filename])
  
  # Create YAML front matter
  yaml_header = <<~YAML
    ---
    title: "#{metadata[:title]}"
    year: #{metadata[:year]}
    type: #{metadata[:type]}
    author: Larry Harvey
    source_url: "#{metadata[:url]}"
    fetched_at: "#{Time.now.strftime('%Y-%m-%d %H:%M')}"
    priority: #{metadata[:priority]}
    word_count: #{content.split.length}
    ---
    
  YAML
  
  File.write(filepath, yaml_header + content)
  puts "  ✓ Created: #{metadata[:filename]} (#{content.split.length} words)"
  
  metadata[:filename]
end

def main
  unless File.exist?(URLS_FILE)
    puts "❌ URLs file not found: #{URLS_FILE}"
    exit 1
  end
  
  # Create output directory
  FileUtils.mkdir_p(OUTPUT_DIR)
  
  # Read and prioritize URLs
  all_urls = File.readlines(URLS_FILE).map(&:strip).reject(&:empty?)
  
  # Sort by priority (1 = highest priority)
  prioritized_urls = all_urls.map do |url|
    metadata = determine_metadata(url)
    { url: url, priority: metadata[:priority] }
  end.sort_by { |item| item[:priority] }
  
  puts "🎭 Fetching Larry Harvey content with Playwright"
  puts "📁 Output directory: #{OUTPUT_DIR}"
  puts "📊 Total URLs: #{all_urls.length}"
  puts ""
  
  # Ask which priority level to fetch
  puts "Priority levels:"
  puts "  1. Core philosophical texts (#{prioritized_urls.count { |u| u[:priority] == 1 }} URLs)"
  puts "  2. Essays and speeches (#{prioritized_urls.count { |u| u[:priority] == 2 }} URLs)" 
  puts "  3. Theme essays and other (#{prioritized_urls.count { |u| u[:priority] == 3 }} URLs)"
  puts ""
  puts "Enter max priority to fetch (1-3, or 'all'): "
  
  response = STDIN.gets.chomp.downcase
  max_priority = case response
                when '1' then 1
                when '2' then 2  
                when '3', 'all' then 3
                else 1
                end
  
  # Filter URLs by priority
  urls_to_fetch = prioritized_urls.select { |item| item[:priority] <= max_priority }
                                 .map { |item| item[:url] }
  
  puts "🚀 Fetching #{urls_to_fetch.length} URLs (priority 1-#{max_priority})"
  puts ""
  
  success_count = 0 
  created_files = []
  
  # Initialize Playwright
  puts "🎭 Starting Playwright browser..."
  
  urls_to_fetch.each_with_index do |url, index|
    puts "[#{index + 1}/#{urls_to_fetch.length}] Processing: #{url}"
    
    metadata = determine_metadata(url)
    
    # Skip if file already exists
    filepath = File.join(OUTPUT_DIR, metadata[:filename])
    if File.exist?(filepath)
      puts "  ⏭️  File already exists: #{metadata[:filename]}"
      next
    end
    
    # Fetch content with Playwright
    raw_content = fetch_with_playwright(url)
    next unless raw_content
    
    # Clean and validate content
    clean_content_text = clean_content(raw_content, url)
    next unless clean_content_text
    
    # Create text file
    filename = create_text_file(clean_content_text, metadata, OUTPUT_DIR)
    if filename
      created_files << filename
      success_count += 1
    end
    
    # Rate limiting - be nice to servers
    sleep(2)
  end
  
  # Close Playwright
  puts ""
  puts "🎭 Closing Playwright browser..."
  
  puts ""
  puts "📊 Extraction Results:"
  puts "   ✅ Successfully fetched: #{success_count}"
  puts "   ❌ Failed: #{urls_to_fetch.length - success_count}"
  puts ""
  
  if created_files.any?
    puts "📝 Created files:"
    created_files.each { |f| puts "   - #{f}" }
    puts ""
    
    puts "🚀 Next steps:"
    puts "   1. Review files in #{OUTPUT_DIR}/"
    puts "   2. Run: rails biographical:import['#{File.expand_path(OUTPUT_DIR)}','Larry Harvey']"
    puts "   3. Test: rails biographical:test_persona['Larry Harvey']"
  else
    puts "❌ No files were created. Check the URLs and try again."
  end
end

if __FILE__ == $0
  main
end