# frozen_string_literal: true

namespace :biographical do
  desc "Import biographical content from text files into the enliterated dataset"
  task :import, [:directory, :persona_name] => :environment do |task, args|
    unless args[:directory] && args[:persona_name]
      puts "Usage: rails biographical:import[/path/to/text/files,'Larry Harvey']"
      puts ""
      puts "Options (set as environment variables):"
      puts "  AUTHOR_ID=person:larry_harvey    # Optional canonical author ID"
      puts "  DEFAULT_YEAR=2010                # Default year if not detected"
      puts "  DRY_RUN=true                     # Preview without importing"
      puts ""
      puts "Expected file formats:"
      puts "  - .txt, .md, or .text files"
      puts "  - YAML front matter supported for metadata"
      puts "  - Year detection from filename (e.g., 'speech_2004.txt')"
      puts "  - Title detection from first line or YAML"
      exit 1
    end
    
    directory = args[:directory]
    persona_name = args[:persona_name]
    author_id = ENV['AUTHOR_ID']
    default_year = ENV['DEFAULT_YEAR']&.to_i || 2024
    dry_run = ENV['DRY_RUN'] == 'true'
    
    puts "Biographical Content Import"
    puts "=" * 50
    puts "Directory: #{directory}"
    puts "Persona: #{persona_name}"
    puts "Author ID: #{author_id || 'auto-generated'}"
    puts "Default Year: #{default_year}"
    puts "Dry Run: #{dry_run ? 'YES' : 'NO'}"
    puts ""
    
    unless Dir.exist?(directory)
      puts "❌ Directory not found: #{directory}"
      exit 1
    end
    
    # Preview files
    text_files = Dir.glob(File.join(directory, "**/*.{txt,md,text}"))
    
    if text_files.empty?
      puts "❌ No text files found in #{directory}"
      puts "Looking for: *.txt, *.md, *.text"
      exit 1
    end
    
    puts "Found #{text_files.length} text files:"
    text_files.each_with_index do |file, i|
      size_kb = (File.size(file) / 1024.0).round(1)
      puts "  #{i+1}. #{File.basename(file)} (#{size_kb}KB)"
    end
    puts ""
    
    if dry_run
      puts "🔍 DRY RUN MODE - Preview only"
      puts ""
      
      text_files.first(3).each do |file|
        puts "Preview: #{File.basename(file)}"
        puts "-" * 30
        
        content = File.read(file, encoding: 'UTF-8')
        preview = content[0, 500]
        preview += "..." if content.length > 500
        
        puts preview
        puts ""
        puts "Word count: #{content.split.length}"
        puts "Estimated type: #{determine_item_type_preview(content, File.basename(file))}"
        puts ""
      end
      
      puts "To import for real: Remove DRY_RUN=true"
      exit 0
    end
    
    # Confirm import
    puts "⚠️  This will import #{text_files.length} files into the enliterated dataset."
    puts "Continue? (y/N)"
    
    response = STDIN.gets.chomp.downcase
    unless response == 'y' || response == 'yes'
      puts "Import cancelled."
      exit 0
    end
    
    # Perform import
    puts "🚀 Starting import..."
    puts ""
    
    service = Search::BiographicalContentImportService.new
    results = service.import_text_files(
      directory,
      persona_name: persona_name,
      author_id: author_id,
      default_year: default_year
    )
    
    puts ""
    puts "Import Results"
    puts "=" * 50
    
    if results[:success]
      puts "✅ Import completed successfully"
      puts "   Imported: #{results[:imported]} files"
      puts "   Failed: #{results[:failed]} files"
      puts ""
      
      if results[:items].any?
        puts "Imported Items:"
        results[:items].each do |item|
          puts "  ✓ #{item.name} (#{item.item_type}, #{item.year})"
          puts "    UID: #{item.uid}"
          puts "    Words: #{item.metadata['word_count']}"
          puts ""
        end
      end
      
      if results[:errors].any?
        puts "Errors:"
        results[:errors].each do |error|
          puts "  ❌ #{File.basename(error[:file])}: #{error[:error]}"
        end
        puts ""
      end
      
      puts "Next Steps:"
      puts "1. Test persona style: rails biographical:test_persona['#{persona_name}']"
      puts "2. Check dataset: SearchableItem.where(item_type: ['essay', 'speech', 'philosophical_text']).count"
      puts "3. Rebuild persona cache: rails biographical:rebuild_persona['#{persona_name}']"
      
    else
      puts "❌ Import failed: #{results[:error]}"
      exit 1
    end
  end
  
  desc "Test persona style after importing biographical content"
  task :test_persona, [:persona_name] => :environment do |task, args|
    unless args[:persona_name]
      puts "Usage: rails biographical:test_persona['Larry Harvey']"
      exit 1
    end
    
    persona_name = args[:persona_name]
    
    puts "Testing Persona Style: #{persona_name}"
    puts "=" * 50
    
    # Enable persona style for testing
    Rails.application.config.x.persona_style.enabled = true
    
    # Test MCP set_persona
    result = Mcp::SetPersonaTool.call(
      persona: persona_name,
      style_mode: "medium",
      require_rights: "any" # Use "any" to include all imported content
    )
    
    if result[:ok]
      puts "✅ Persona style successful"
      puts "   Confidence: #{result[:style_confidence]}"
      puts "   Sources: #{result[:sources].length}"
      puts "   Quotable: #{result[:rights_summary][:quotable]}"
      puts ""
      
      puts "Style Capsule:"
      puts "  Tone: #{result[:style_capsule][:tone].join(', ')}"
      puts "  Cadence: #{result[:style_capsule][:cadence]}"
      puts "  Key vocabulary: #{result[:style_capsule][:vocabulary].first(10).join(', ')}"
      puts "  Metaphors: #{result[:style_capsule][:metaphors].first(5).join(', ')}"
      puts ""
      
      puts "Sources:"
      result[:sources].each do |source|
        puts "  - #{source[:title]} (#{source[:year]})"
      end
      
    else
      puts "❌ Persona style failed: #{result[:error]}"
      puts "Error code: #{result[:error_code]}" if result[:error_code]
    end
  end
  
  desc "Rebuild persona cache after adding new content"
  task :rebuild_persona, [:persona_name] => :environment do |task, args|
    unless args[:persona_name]
      puts "Usage: rails biographical:rebuild_persona['Larry Harvey']"
      exit 1
    end
    
    persona_name = args[:persona_name]
    
    puts "Rebuilding Persona Cache: #{persona_name}"
    puts "=" * 50
    
    # Clear existing cache entries
    persona_id = "person:#{persona_name.downcase.gsub(/\s+/, '_')}"
    
    # Find and delete existing StyleCapsules
    existing_capsules = StyleCapsule.where(persona_id: persona_id)
    if existing_capsules.any?
      count = existing_capsules.count
      existing_capsules.delete_all
      puts "🗑️  Cleared #{count} existing style capsules"
    end
    
    # Clear cache entries
    cache_patterns = [
      "style_capsule:#{persona_id}:*",
    ]
    
    # Note: Rails.cache doesn't support pattern deletion easily
    # In production with Redis, you'd use: Rails.cache.redis.keys(pattern).each { |k| Rails.cache.delete(k) }
    puts "🗑️  Cache cleared (manual clear may be needed in production)"
    
    # Rebuild with background job
    BuildStyleCapsuleJob.perform_later(
      persona_id: persona_id,
      persona_label: persona_name
    )
    
    puts "🚀 Rebuild job enqueued"
    puts "   Check progress: rails biographical:test_persona['#{persona_name}']"
  end
  
  desc "List biographical content in dataset"
  task :list => :environment do
    puts "Biographical Content in Dataset"
    puts "=" * 50
    
    biographical_types = ['essay', 'speech', 'philosophical_text', 'manifesto', 'interview', 'letter', 'note']
    
    biographical_types.each do |type|
      items = SearchableItem.where(item_type: type)
      next if items.empty?
      
      puts "\n#{type.humanize.titleize} (#{items.count}):"
      items.order(:year, :name).each do |item|
        author = item.metadata&.dig('author') || 'Unknown'
        puts "  - #{item.name} by #{author} (#{item.year})"
      end
    end
    
    total = SearchableItem.where(item_type: biographical_types).count
    puts "\nTotal biographical items: #{total}"
  end
  
  private
  
  def determine_item_type_preview(content, filename)
    content_lower = content.downcase
    filename_lower = filename.downcase
    
    case
    when filename_lower.include?('principle') || content_lower.include?('principle')
      'philosophical_text'
    when filename_lower.include?('speech') || filename_lower.include?('address')
      'speech'
    when filename_lower.include?('essay') || filename_lower.include?('writing')
      'essay'
    when filename_lower.include?('manifesto') || filename_lower.include?('statement')
      'manifesto'
    else
      'essay'
    end
  end
end