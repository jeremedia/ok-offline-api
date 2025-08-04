require 'bundler/setup'
require 'himg'

# Test with background and content layers
html = <<~HTML
  <!DOCTYPE html>
  <html>
  <body style="margin:0; width:1200px; height:630px; background:black; position:relative;">
    <img src="file://#{File.expand_path('public/ok_logos/ok_bg_img.png')}" 
         style="position:absolute; top:0; left:0; width:1200px; height:630px; opacity:0.5;">
    <div style="position:absolute; top:0; left:0; width:100%; height:100%; display:flex; align-items:center; justify-content:center;">
      <h1 style="color:white; font-size:72px; margin:0;">OK-OFFLINE</h1>
      <img src="file://#{File.expand_path('public/ok_logos/oknotok_circle_mark.png')}" 
           style="width:200px; height:200px; margin-left:50px;">
    </div>
  </body>
  </html>
HTML

puts "Testing layered rendering..."

begin
  png_data = Himg.render(html, width: 1200, height: 630)
  File.open("test_bg_layers.png", "wb") { |f| f.write(png_data) }
  puts "✅ Saved test_bg_layers.png (#{png_data.bytesize} bytes)"
rescue => e
  puts "❌ Failed: #{e.message}"
end