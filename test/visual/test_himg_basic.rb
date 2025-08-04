require 'bundler/setup'
require 'himg'

# Test basic himg functionality
puts "Testing basic himg rendering..."

begin
  # Simple HTML without any external resources
  html = <<~HTML
    <html>
      <body style='background: blue; color: white; font-size: 48px; text-align: center; padding: 100px;'>
        <div>OK-OFFLINE</div>
      </body>
    </html>
  HTML
  
  png_data = Himg.render(html, width: 800, height: 400)
  
  File.open("test_output.png", "wb") { |f| f.write(png_data) }
  
  puts "✅ Success! Image saved as test_output.png"
  puts "File size: #{png_data.bytesize} bytes"
  
rescue => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace.first(5)
end