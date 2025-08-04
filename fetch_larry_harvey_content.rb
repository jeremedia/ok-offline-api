#!/usr/bin/env ruby
require 'net/http'
require 'uri'
require 'nokogiri'
require 'fileutils'

# Script to fetch Larry Harvey content from URLs and prepare for import
# Usage: ruby fetch_larry_harvey_content.rb

URLS_FILE = 'larry_harvey_urls.txt'
OUTPUT_DIR = 'larry_harvey_writings'

# URL to filename mapping with metadata
URL_MAPPINGS = {
  'introduction-the-philosophical-center' => {
    filename: 'philosophical_center_introduction_2013.txt',
    title: 'Introduction: The Philosophical Center',
    year: 2013,
    type: 'philosophical_text'
  },
  'commerce-community-distilling-philosophy' => {
    filename: 'commerce_community_2013.txt', 
    title: 'Commerce & Community: Distilling philosophy from a cup of coffee',
    year: 2013,
    type: 'philosophical_text'
  },
  'how-the-west-was-won' => {
    filename: 'how_west_was_won_2013.txt',
    title: 'How the West Was Won: Anarchy vs. Civic Responsibility', 
    year: 2013,
    type: 'essay'
  },
  '10-principles' => {
    filename: 'ten_principles_2004.txt',
    title: 'The Ten Principles of Burning Man',
    year: 2004, 
    type: 'philosophical_text'
  },
  'a-guide-to-gifting' => {
    filename: 'guide_to_gifting_2019.txt',
    title: 'A Guide to Gifting, Givers and Gratitude',
    year: 2019,
    type: 'philosophical_text'
  }
  # Add more mappings as needed
}

def fetch_url_content(url)
  puts "Fetching: #{url}"
  
  uri = URI(url)
  response = Net::HTTP.get_response(uri)
  
  if response.code == '200'
    response.body
  else
    puts "  ❌ Failed to fetch: #{response.code}"
    nil
  end
rescue => e
  puts "  ❌ Error: #{e.message}"
  nil
end

def extract_content(html, url)
  doc = Nokogiri::HTML(html)
  
  # Try different content selectors based on site
  content = nil
  
  if url.include?('journal.burningman.org')
    # Burning Man Journal format
    content = doc.css('.entry-content, .post-content, article').first&.text
  elsif url.include?('burningman.org')
    # Main Burning Man site
    content = doc.css('.content, .main-content, article, .entry').first&.text
  elsif url.include?('trippingly.net')
    # Trippingly format
    content = doc.css('.post-content, .entry-content, article').first&.text
  else
    # Generic fallback
    content = doc.css('article, .content, .post, .entry').first&.text
  end
  
  # Clean up the content
  if content
    content = content.strip
               .gsub(/\s+/, ' ')          # Normalize whitespace
               .gsub(/\n\s*\n/, "\n\n")   # Clean paragraph breaks
  end
  
  content
end

def create_text_file(content, metadata, output_dir)
  return unless content && !content.empty?
  
  filepath = File.join(output_dir, metadata[:filename])
  
  # Create YAML front matter
  yaml_header = <<~YAML
    ---
    title: "#{metadata[:title]}"
    year: #{metadata[:year]}
    type: #{metadata[:type]}
    author: Larry Harvey
    source_url: "#{metadata[:url]}"
    fetched_at: "#{Time.now.strftime('%Y-%m-%d')}"
    ---
    
  YAML
  
  File.write(filepath, yaml_header + content)
  puts "  ✓ Created: #{metadata[:filename]} (#{content.length} chars)"
end

# Main execution
def main
  unless File.exist?(URLS_FILE)
    puts "❌ URLs file not found: #{URLS_FILE}"
    exit 1
  end
  
  # Create output directory
  FileUtils.mkdir_p(OUTPUT_DIR)
  
  # Read URLs
  urls = File.readlines(URLS_FILE).map(&:strip).reject(&:empty?)
  
  puts "📥 Fetching content from #{urls.length} URLs..."
  puts "📁 Output directory: #{OUTPUT_DIR}"
  puts ""
  
  success_count = 0
  
  urls.each_with_index do |url, index|
    puts "[#{index + 1}/#{urls.length}] Processing: #{url}"
    
    # Find matching metadata
    metadata = URL_MAPPINGS.find { |key, _| url.include?(key) }&.last
    
    unless metadata
      # Generate fallback metadata from URL
      filename = url.split('/').last.gsub(/[^a-z0-9\-]/, '_') + '.txt'
      metadata = {
        filename: filename,
        title: filename.gsub(/[_-]/, ' ').gsub('.txt', '').titleize,
        year: 2024,  # Default year
        type: 'essay',
        url: url
      }
    else
      metadata[:url] = url
    end
    
    # Fetch and process content
    html = fetch_url_content(url)
    next unless html
    
    content = extract_content(html, url)
    next unless content && content.length > 100  # Skip if too short
    
    create_text_file(content, metadata, OUTPUT_DIR)
    success_count += 1
    
    # Be nice to servers
    sleep(1)
  end
  
  puts ""
  puts "📊 Results:"
  puts "   ✅ Successfully fetched: #{success_count}"
  puts "   ❌ Failed: #{urls.length - success_count}"
  puts ""
  puts "Next steps:"
  puts "   1. Review files in #{OUTPUT_DIR}/"
  puts "   2. Edit any files that need cleanup"
  puts "   3. Run: rails biographical:import['#{File.expand_path(OUTPUT_DIR)}','Larry Harvey']"
end

if __FILE__ == $0
  main
end