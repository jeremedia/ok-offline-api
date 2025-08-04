require 'bundler/setup'
require 'himg'

# Test himg with local file URLs
html = <<~HTML
  <!DOCTYPE html>
  <html>
  <head>
    <style>
      body {
        width: 1200px;
        height: 630px;
        margin: 0;
        padding: 40px;
        background: black;
        color: white;
        font-family: monospace;
        position: relative;
      }
      .bg {
        position: absolute;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background-image: url('file://#{File.expand_path('public/ok_logos/ok_bg_img.jpeg')}');
        background-size: cover;
        opacity: 0.5;
        z-index: 0;
      }
      .content {
        position: relative;
        z-index: 1;
      }
      img {
        width: 200px;
        position: absolute;
        right: 40px;
        top: 40px;
      }
    </style>
  </head>
  <body>
    <div class="bg"></div>
    <div class="content">
      <h1>Test with Assets</h1>
      <p>This should have a background image and logo</p>
    </div>
    <img src="file://#{File.expand_path('public/ok_logos/oknotok_circle_mark.png')}" alt="Logo">
  </body>
  </html>
HTML

puts "Testing himg with local assets..."
puts "Background: file://#{File.expand_path('public/ok_logos/ok_bg_img.jpeg')}"
puts "Logo: file://#{File.expand_path('public/ok_logos/oknotok_circle_mark.png')}"

begin
  png_data = Himg.render(html, width: 1200, height: 630)
  File.open("test_with_assets.png", "wb") { |f| f.write(png_data) }
  puts "✅ Success! Saved as test_with_assets.png (#{png_data.bytesize} bytes)"
rescue => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace.first(5)
end