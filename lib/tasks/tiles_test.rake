namespace :tiles do
  desc "Test tile download with a small sample"
  task test: :environment do
    require 'net/http'
    require 'zip'
    require 'fileutils'
    
    # Test with just zoom level 12 (should be ~4 tiles)
    bounds = {
      north: 40.807,
      south: 40.764,
      east: -119.176,
      west: -119.233
    }
    
    zoom = 12
    output_path = Rails.root.join('public', 'tiles', 'test-package.zip')
    
    FileUtils.mkdir_p(File.dirname(output_path))
    
    puts "Testing tile download for zoom level #{zoom}..."
    
    # Calculate tiles
    min_tile = lat_lng_to_tile(bounds[:south], bounds[:west], zoom)
    max_tile = lat_lng_to_tile(bounds[:north], bounds[:east], zoom)
    
    width = (max_tile[:x] - min_tile[:x]).abs + 1
    height = (max_tile[:y] - min_tile[:y]).abs + 1
    total_tiles = width * height
    
    puts "Tiles to download: #{total_tiles} (#{min_tile[:x]}..#{max_tile[:x]}, #{max_tile[:y]}..#{min_tile[:y]})"
    
    # Create ZIP
    Zip::File.open(output_path, create: true) do |zipfile|
      (min_tile[:x]..max_tile[:x]).each do |x|
        (max_tile[:y]..min_tile[:y]).each do |y|
          begin
            puts "Downloading tile #{zoom}/#{x}/#{y}..."
            tile_data = download_tile(zoom, x, y)
            zipfile.get_output_stream("tiles/#{zoom}/#{x}/#{y}.png") { |f| f.write(tile_data) }
            puts "✓ Saved to ZIP"
          rescue => e
            puts "✗ Failed: #{e.message}"
          end
        end
      end
    end
    
    file_size_kb = (File.size(output_path) / 1024.0).round(2)
    puts "\n✅ Test package created: #{output_path}"
    puts "   Size: #{file_size_kb} KB"
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
    request['User-Agent'] = 'OK-OFFLINE Test (offline.oknotok.com)'
    
    response = http.request(request)
    
    if response.code == '200'
      response.body
    else
      raise "HTTP #{response.code}: #{response.message}"
    end
  end
end