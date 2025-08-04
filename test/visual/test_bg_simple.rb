require 'bundler/setup'
require 'himg'

# Test with just the background image
html = <<~HTML
  <!DOCTYPE html>
  <html>
  <body style="margin:0; width:1200px; height:630px;">
    <img src="file://#{File.expand_path('public/ok_logos/ok_bg_img.png')}" 
         style="width:1200px; height:630px; display:block;">
  </body>
  </html>
HTML

puts "Testing background image rendering..."
puts "Image path: file://#{File.expand_path('public/ok_logos/ok_bg_img.png')}"

begin
  png_data = Himg.render(html, width: 1200, height: 630)
  File.open("test_bg_only.png", "wb") { |f| f.write(png_data) }
  puts "✅ Saved test_bg_only.png (#{png_data.bytesize} bytes)"
rescue => e
  puts "❌ Failed: #{e.message}"
end