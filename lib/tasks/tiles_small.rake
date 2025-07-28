namespace :tiles do
  desc "Create a smaller tile package (zoom 12-15) for testing"
  task create_small_package: :environment do
    require 'net/http'
    require 'zip'
    require 'fileutils'
    
    # BRC bounds
    bounds = {
      north: 40.807,
      south: 40.764,
      east: -119.176,
      west: -119.233
    }
    
    zoom_levels = (12..15)  # Reduced for testing
    temp_dir = Rails.root.join('tmp', 'tiles')
    output_path = Rails.root.join('public', 'tiles', 'package.zip')
    
    FileUtils.mkdir_p(temp_dir)
    FileUtils.mkdir_p(File.dirname(output_path))
    
    total_tiles = 0
    downloaded_tiles = 0
    
    # Calculate total tiles
    zoom_levels.each do |zoom|
      min_tile = lat_lng_to_tile(bounds[:south], bounds[:west], zoom)
      max_tile = lat_lng_to_tile(bounds[:north], bounds[:east], zoom)
      
      width = (max_tile[:x] - min_tile[:x]).abs + 1
      height = (max_tile[:y] - min_tile[:y]).abs + 1
      total_tiles += width * height
    end
    
    puts "Total tiles to download: #{total_tiles} (zoom levels #{zoom_levels.to_a.join(', ')})"
    
    # Download tiles
    zoom_levels.each do |zoom|
      min_tile = lat_lng_to_tile(bounds[:south], bounds[:west], zoom)
      max_tile = lat_lng_to_tile(bounds[:north], bounds[:east], zoom)
      
      puts "\nZoom level #{zoom}: #{min_tile[:x]}..#{max_tile[:x]}, #{max_tile[:y]}..#{min_tile[:y]}"
      
      (min_tile[:x]..max_tile[:x]).each do |x|
        (max_tile[:y]..min_tile[:y]).each do |y|
          begin
            tile_data = download_tile(zoom, x, y)
            
            # Save to temp directory
            tile_dir = temp_dir.join(zoom.to_s, x.to_s)
            FileUtils.mkdir_p(tile_dir)
            File.binwrite(tile_dir.join("#{y}.png"), tile_data)
            
            downloaded_tiles += 1
            
            if downloaded_tiles % 5 == 0
              progress = (downloaded_tiles.to_f / total_tiles * 100).round
              puts "Progress: #{downloaded_tiles}/#{total_tiles} (#{progress}%)"
            end
            
            # Rate limit to be respectful to OSM
            sleep 0.15
          rescue => e
            puts "Failed to download tile #{zoom}/#{x}/#{y}: #{e.message}"
          end
        end
      end
    end
    
    # Create ZIP package
    puts "\nCreating ZIP package..."
    
    Zip::File.open(output_path, create: true) do |zipfile|
      Dir[temp_dir.join('**', '*.png')].each do |file|
        relative_path = file.sub("#{temp_dir}/", '')
        zipfile.add("tiles/#{relative_path}", file)
      end
    end
    
    # Clean up temp files
    FileUtils.rm_rf(temp_dir)
    
    file_size_mb = (File.size(output_path) / 1024.0 / 1024.0).round(2)
    puts "\n✅ Tile package created: #{output_path}"
    puts "   Size: #{file_size_mb} MB"
    puts "   Tiles: #{downloaded_tiles}/#{total_tiles}"
  end
  
  private
  
  def lat_lng_to_tile(lat, lng, zoom)
    x = ((lng + 180) / 360 * (2 ** zoom)).floor
    y = ((1 - Math.log(Math.tan(lat * Math::PI / 180) + 1 / Math.cos(lat * Math::PI / 180)) / Math::PI) / 2 * (2 ** zoom)).floor
    { x: x, y: y }
  end
  
  def download_tile(z, x, y)
    subdomains = ['a', 'b', 'c']
    s = subdomains[(x + y).abs % subdomains.length]
    uri = URI("https://#{s}.tile.openstreetmap.org/#{z}/#{x}/#{y}.png")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 10
    
    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = 'OK-OFFLINE Burning Man App (offline.oknotok.com)'
    
    response = http.request(request)
    
    if response.code == '200'
      response.body
    else
      raise "HTTP #{response.code}: #{response.message}"
    end
  end
end