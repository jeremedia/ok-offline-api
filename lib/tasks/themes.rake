namespace :themes do
  desc "Import themes from frontend themes.json file"
  task import: :environment do
    json_path = Rails.root.join('..', 'frontend', 'public', 'data', 'themes.json')
    
    # Check for worktree versions if main doesn't exist
    unless File.exist?(json_path)
      worktree_paths = Dir.glob(Rails.root.join('..', 'frontend-*', 'public', 'data', 'themes.json'))
      if worktree_paths.any?
        json_path = worktree_paths.first
        puts "Using worktree themes.json: #{json_path}"
      else
        puts "Themes JSON file not found at #{json_path}"
        exit 1
      end
    end
    
    data = JSON.parse(File.read(json_path))
    themes_data = data['themes'] || {}
    
    puts "Importing #{themes_data.length} themes..."
    
    themes_data.each_with_index do |(theme_id, theme_data), index|
      puts "Processing theme: #{theme_data['name']} (#{theme_id})"
      
      theme = Theme.find_or_initialize_by(theme_id: theme_id)
      
      theme.update!(
        name: theme_data['name'],
        description: theme_data['description'] || '',
        colors: theme_data['colors'] || {},
        typography: theme_data['typography'],
        position: index,
        active: true
      )
      
      puts "  ✓ Imported #{theme.name}"
    end
    
    puts "\nImport complete! #{Theme.count} themes in database."
    
    # Show summary
    puts "\nThemes by name:"
    Theme.ordered.each do |theme|
      puts "  - #{theme.name} (#{theme.theme_id})"
    end
  end
  
  desc "Export themes from database to JSON format"
  task export: :environment do
    output_path = Rails.root.join('themes_export.json')
    
    themes_hash = {}
    Theme.active.ordered.each do |theme|
      themes_hash[theme.theme_id] = theme.to_theme_format
    end
    
    export_data = { themes: themes_hash }
    
    File.write(output_path, JSON.pretty_generate(export_data))
    puts "Exported #{themes_hash.length} themes to #{output_path}"
  end
  
  desc "Clear all themes from database"
  task clear: :environment do
    puts "Clearing all theme data..."
    Theme.destroy_all
    puts "All themes cleared."
  end
  
  desc "Show themes statistics"
  task stats: :environment do
    puts "Theme Statistics:"
    puts "  Total themes: #{Theme.count}"
    puts "  Active themes: #{Theme.active.count}"
    puts "  Inactive themes: #{Theme.where(active: false).count}"
    puts
    
    puts "Themes by name:"
    Theme.ordered.each do |theme|
      status = theme.active? ? "✓" : "✗"
      puts "  #{status} #{theme.name} (#{theme.theme_id}) - #{theme.colors.keys.length} colors"
    end
  end
end