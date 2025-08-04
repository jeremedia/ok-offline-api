#!/usr/bin/env ruby
require_relative 'config/environment'
require 'fileutils'

# Simple Larry Harvey content fetcher using direct MCP tool calls
# Usage: ruby fetch_larry_harvey_simple.rb

OUTPUT_DIR = 'larry_harvey_writings'

# Priority 1 URLs - Core philosophical texts (start with these)
PRIORITY_1_URLS = [
  {
    url: 'https://burningman.org/about/10-principles/',
    filename: 'ten_principles_2004.txt',
    title: 'The Ten Principles of Burning Man',
    year: 2004,
    type: 'philosophical_text'
  },
  {
    url: 'https://journal.burningman.org/2013/11/philosophical-center/tenprinciples/introduction-the-philosophical-center/',
    filename: 'philosophical_center_introduction_2013.txt',
    title: 'Introduction: The Philosophical Center',
    year: 2013,
    type: 'philosophical_text'
  },
  {
    url: 'https://journal.burningman.org/2013/11/philosophical-center/tenprinciples/commerce-community-distilling-philosophy-from-a-cup-of-coffee/',
    filename: 'commerce_community_2013.txt',
    title: 'Commerce & Community: Distilling philosophy from a cup of coffee',
    year: 2013,
    type: 'philosophical_text'
  },
  {
    url: 'https://journal.burningman.org/2019/06/philosophical-center/tenprinciples/a-guide-to-gifting-givers-and-gratitude-a-treatise-from-the-philosophical-center/',
    filename: 'guide_to_gifting_2019.txt',
    title: 'A Guide to Gifting, Givers and Gratitude',
    year: 2019,
    type: 'philosophical_text'
  },
  {
    url: 'https://journal.burningman.org/2013/11/philosophical-center/tenprinciples/how-the-west-was-won-anarchy-vs-civic-responsibility/',
    filename: 'how_west_was_won_2013.txt',
    title: 'How the West Was Won: Anarchy vs. Civic Responsibility',
    year: 2013,
    type: 'essay'
  }
]

def fetch_url_with_mcp_playwright(url)
  puts "🎭 Fetching: #{url}"
  
  begin
    # Navigate to URL using MCP Playwright tool
    nav_result = mcp__playwright__playwright_navigate(
      url: url,
      timeout: 30000,
      waitUntil: 'networkidle'
    )
    
    unless nav_result[:success]
      puts "  ❌ Navigation failed: #{nav_result[:error]}"
      return nil
    end
    
    # Wait for content to fully render
    sleep(2)
    
    # Get visible text using MCP Playwright tool
    text_result = mcp__playwright__playwright_get_visible_text
    
    if text_result[:text] && text_result[:text].length > 200
      puts "  ✓ Extracted #{text_result[:text].length} characters"
      return text_result[:text]
    else
      puts "  ❌ No substantial text content found"
      return nil
    end
    
  rescue => e
    puts "  ❌ Playwright error: #{e.message}"
    return nil
  end
end

def clean_content(raw_content)
  return nil unless raw_content && raw_content.length > 200
  
  # Remove common website navigation elements
  content = raw_content.dup
  
  # Remove navigation noise
  noise_patterns = [
    /Skip to (?:main )?content/i,
    /Menu\s+/i,
    /Navigation/i,
    /Search\s+/i,
    /Home\s+About\s+/i,
    /Subscribe\s+/i,
    /Share this/i,
    /Print\s+/i,
    /Email\s+/i,
    /Facebook\s+Twitter\s+/i,
    /← Previous\s+Next →/i,
    /Related Posts/i,
    /Comments/i
  ]
  
  noise_patterns.each do |pattern|
    content.gsub!(pattern, '')
  end
  
  # Clean up whitespace and formatting
  content = content.strip
                   .gsub(/\n\s*\n\s*\n+/, "\n\n")  # Multiple newlines to double
                   .gsub(/[ \t]+/, ' ')             # Multiple spaces to single
                   .gsub(/^\s+/, '')                # Leading whitespace
  
  # Look for main content start (after navigation)
  content_start_markers = [
    /The Ten Principles/i,
    /Introduction/i,
    /Essay/i,
    /Article/i,
    /By Larry Harvey/i,
    /\d{4}/  # Year
  ]
  
  content_start_markers.each do |marker|
    if match = content.match(marker)
      start_pos = match.begin(0)
      # Only use if we found it after some navigation content
      if start_pos > 50 && start_pos < content.length / 2
        content = content[start_pos..-1]
        break
      end
    end
  end
  
  # Final length check
  return nil if content.length < 500
  
  content
end

def create_text_file(content, metadata, output_dir)
  return nil unless content && content.length > 500
  
  filepath = File.join(output_dir, metadata[:filename])
  
  yaml_header = <<~YAML
    ---
    title: "#{metadata[:title]}"
    year: #{metadata[:year]}
    type: #{metadata[:type]}
    author: Larry Harvey
    source_url: "#{metadata[:url]}"
    fetched_at: "#{Time.now.strftime('%Y-%m-%d %H:%M')}"
    word_count: #{content.split.length}
    ---
    
  YAML
  
  File.write(filepath, yaml_header + content)
  puts "  ✓ Created: #{metadata[:filename]} (#{content.split.length} words)"
  
  true
end

def main
  puts "🎭 Larry Harvey Content Fetcher (Playwright MCP)"
  puts "=" * 60
  
  # Create output directory
  FileUtils.mkdir_p(OUTPUT_DIR)
  puts "📁 Output directory: #{File.expand_path(OUTPUT_DIR)}"
  puts ""
  
  success_count = 0
  
  PRIORITY_1_URLS.each_with_index do |item, index|
    puts "[#{index + 1}/#{PRIORITY_1_URLS.length}] #{item[:title]}"
    
    # Skip if file already exists
    filepath = File.join(OUTPUT_DIR, item[:filename])
    if File.exist?(filepath)
      puts "  ⏭️  Already exists: #{item[:filename]}"
      next
    end
    
    # Fetch content
    raw_content = fetch_url_with_mcp_playwright(item[:url])
    next unless raw_content
    
    # Clean content
    cleaned_content = clean_content(raw_content)
    next unless cleaned_content
    
    # Create file
    if create_text_file(cleaned_content, item, OUTPUT_DIR)
      success_count += 1
    end
    
    # Rate limiting
    sleep(2)
  end
  
  # Close browser
  puts ""
  puts "🎭 Closing Playwright browser..."
  begin
    mcp__playwright__playwright_close
    puts "  ✓ Browser closed"
  rescue => e
    puts "  ⚠️  Browser close error (may already be closed): #{e.message}"
  end
  
  puts ""
  puts "📊 Results:"
  puts "   ✅ Successfully created: #{success_count} files"
  puts "   ❌ Failed: #{PRIORITY_1_URLS.length - success_count}"
  
  if success_count > 0
    puts ""
    puts "🚀 Next steps:"
    puts "   rails biographical:import['#{File.expand_path(OUTPUT_DIR)}','Larry Harvey']"
    puts "   rails biographical:test_persona['Larry Harvey']"
  end
end

if __FILE__ == $0
  main
end