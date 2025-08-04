require 'bundler/setup'
require 'himg'

# Test 1: Simple image tag
html1 = <<~HTML
  <!DOCTYPE html>
  <html>
  <body style="margin:0; width:600px; height:300px; background:black; position:relative;">
    <img src="file://#{File.expand_path('public/ok_logos/oknotok_circle_mark.png')}" 
         style="width:100px; height:100px; position:absolute; top:10px; right:10px;">
    <div style="color:white; padding:20px;">Test 1: Image tag</div>
  </body>
  </html>
HTML

# Test 2: With background div
html2 = <<~HTML
  <!DOCTYPE html>
  <html>
  <body style="margin:0; width:600px; height:300px; background:black; position:relative;">
    <div style="position:absolute; top:0; left:0; width:100%; height:100%; 
                background:linear-gradient(red, blue); opacity:0.5;"></div>
    <div style="color:white; padding:20px; position:relative; z-index:1;">Test 2: Background div</div>
  </body>
  </html>
HTML

[html1, html2].each_with_index do |html, i|
  begin
    png_data = Himg.render(html, width: 600, height: 300)
    File.open("test_debug_#{i+1}.png", "wb") { |f| f.write(png_data) }
    puts "✅ Test #{i+1} saved (#{png_data.bytesize} bytes)"
  rescue => e
    puts "❌ Test #{i+1} failed: #{e.message}"
  end
end