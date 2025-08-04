# frozen_string_literal: true

module Api
  module V1
    class OpengraphController < BaseController
      def test
        # Generate HTML with HTTP URLs for browser testing
        html = generate_html_for_browser(
          params[:title] || 'OK-OFFLINE TEST',
          params[:subtitle] || 'This is a test render',
          params[:year] || Date.current.year,
          request.base_url
        )
        render html: html.html_safe
      end
      
      def preview
        # OpenGraph preview tool
        render html: preview_page_html.html_safe
      end
      
      def fetch_og_data
        url = params[:url]
        
        if url.blank?
          render json: { error: 'URL is required' }, status: :bad_request
          return
        end
        
        begin
          # Fetch the page content
          uri = URI.parse(url)
          response = Net::HTTP.get_response(uri)
          
          if response.code != '200'
            render json: { error: "Failed to fetch URL: #{response.code}" }, status: :unprocessable_entity
            return
          end
          
          # Parse OpenGraph tags
          html_doc = Nokogiri::HTML(response.body)
          og_data = extract_og_tags(html_doc)
          og_data[:url] = url
          
          render json: og_data
        rescue => e
          render json: { error: "Failed to fetch URL: #{e.message}" }, status: :unprocessable_entity
        end
      end
      
      def generate
        validate_params!
        
        begin
          # Generate cache key based on parameters
          cache_key = generate_cache_key(params[:title], params[:subtitle], params[:year])
          filename = "og_#{cache_key}.png"
          filepath = Rails.root.join('public', 'opengraph', filename)
          
          # Check if image already exists
          if File.exist?(filepath)
            Rails.logger.info "Returning cached OpenGraph image: #{filename}"
            image_url = "#{request.base_url}/opengraph/#{filename}"
            render json: {
              success: true,
              url: image_url,
              width: 1200,
              height: 630,
              cached: true
            }
            return
          end
          
          # Generate simple HTML without external resources for now
          html = generate_simple_html(params[:title], params[:subtitle], params[:year])
          
          # Create directory if needed
          FileUtils.mkdir_p(filepath.dirname)
          
          # Write HTML to temp file
          temp_html = Rails.root.join('tmp', "#{filename}.html")
          File.write(temp_html, html)
          
          # Also save a copy in public for debugging
          debug_html = Rails.root.join('public', 'opengraph', "#{filename}.html")
          File.write(debug_html, html)
          
          # Use a separate Ruby process to avoid crashes
          script = <<~RUBY
            require 'bundler/setup'
            require 'himg'
            
            html = File.read('#{temp_html}')
            puts "Rendering HTML with himg..."
            png_data = Himg.render(html, width: 1200, height: 630)
            File.open('#{filepath}', 'wb') { |f| f.write(png_data) }
            puts "Saved PNG: \#{png_data.bytesize} bytes"
          RUBY
          
          # Execute in subprocess with output capture
          output = `ruby -e "#{script.gsub('"', '\"')}" 2>&1`
          result = $?.success?
          Rails.logger.info "Himg output: #{output}" if output.present?
          
          # Clean up temp file
          File.delete(temp_html) if File.exist?(temp_html)
          
          if result && File.exist?(filepath)
            image_url = "#{request.base_url}/opengraph/#{filename}"
            render json: {
              success: true,
              url: image_url,
              width: 1200,
              height: 630,
              cached: false
            }
          else
            render json: { error: "Failed to generate image" }, status: :internal_server_error
          end
        rescue => e
          Rails.logger.error "OpenGraph generation error: #{e.message}"
          Rails.logger.error e.backtrace.first(10).join("\n")
          render json: { error: "Failed to generate image: #{e.message}" }, status: :internal_server_error
        end
      end
      
      private
      
      def validate_params!
        # Use default title if none provided
        params[:title] = 'OK-OFFLINE' if params[:title].blank?
        
        raise ArgumentError, 'Title too long (max 100 chars)' if params[:title].length > 100
        raise ArgumentError, 'Subtitle too long (max 200 chars)' if params[:subtitle]&.length.to_i > 200
      end
      
      def extract_og_tags(doc)
        og_data = {}
        
        # Extract all og: meta tags
        doc.css('meta[property^="og:"]').each do |meta|
          property = meta['property'].sub('og:', '')
          content = meta['content']
          og_data[property] = content if content.present?
        end
        
        # Also get the title tag if no og:title
        og_data['title'] ||= doc.at_css('title')&.text&.strip
        
        # Get Twitter card data as fallback
        doc.css('meta[name^="twitter:"]').each do |meta|
          property = "twitter_#{meta['name'].sub('twitter:', '')}"
          content = meta['content']
          og_data[property] = content if content.present?
        end
        
        og_data
      end
      
      def render_opengraph_image
        ::Himg.render(
          render_to_string(
            template: 'opengraph/simple',
            formats: [:himg],
            layout: false,
            locals: {
              title: params[:title],
              subtitle: params[:subtitle],
              year: params[:year] || Date.current.year,
              base_url: request.base_url
            }
          ),
          width: 1200,
          height: 630
        )
      end
      
      def generate_html_for_browser(title, subtitle, year, base_url)
        # Same HTML but with HTTP URLs for browser testing
        html_template(title, subtitle, year, 
          "#{base_url}/fonts",
          "#{base_url}/ok_logos/oknotok_circle_mark.png",
          "#{base_url}/ok_logos/ok_bg_img.png",
          true
        )
      end
      
      def generate_simple_html(title, subtitle, year)
        # Use file:// URLs for himg
        fonts_path = "file://#{Rails.root.join('public', 'fonts')}"
        logo_path = "file://#{Rails.root.join('public', 'ok_logos', 'oknotok_circle_mark.png')}"
        bg_path = "file://#{Rails.root.join('public', 'ok_logos', 'oknotok_circle_mark.png')}"
        
        html_template(title, subtitle, year, fonts_path, logo_path, bg_path, false)
      end
      
      def generate_cache_key(title, subtitle, year)
        # Create a deterministic hash for the same parameters
        normalized_title = title&.strip&.downcase || 'ok-offline'
        normalized_subtitle = subtitle&.strip&.downcase || ''
        normalized_year = year || Date.current.year
        
        # Create a stable hash from the normalized parameters
        content = "#{normalized_title}|#{normalized_subtitle}|#{normalized_year}"
        Digest::MD5.hexdigest(content)[0..15]
      end
      
      def preview_page_html
        <<~HTML
          <!DOCTYPE html>
          <html lang="en">
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>OpenGraph Preview Tool</title>
            <style>
              * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
              }
              
              body {
                font-family: 'Berkeley Mono', monospace, system-ui;
                background: #1a1a1a;
                color: #fff;
                padding: 40px 20px;
                min-height: 100vh;
              }
              
              .container {
                max-width: 1200px;
                margin: 0 auto;
              }
              
              h1 {
                font-size: 2.5rem;
                margin-bottom: 10px;
                color: #ff3333;
              }
              
              .subtitle {
                font-size: 1.2rem;
                color: #999;
                margin-bottom: 40px;
              }
              
              .form-group {
                margin-bottom: 30px;
              }
              
              label {
                display: block;
                margin-bottom: 10px;
                font-size: 1.1rem;
              }
              
              input[type="url"] {
                width: 100%;
                padding: 15px 20px;
                font-size: 1.1rem;
                background: #2a2a2a;
                border: 2px solid #444;
                color: #fff;
                border-radius: 8px;
                font-family: inherit;
              }
              
              input[type="url"]:focus {
                outline: none;
                border-color: #ff3333;
              }
              
              button {
                background: #ff3333;
                color: #fff;
                border: none;
                padding: 15px 40px;
                font-size: 1.1rem;
                border-radius: 8px;
                cursor: pointer;
                font-family: inherit;
                font-weight: bold;
              }
              
              button:hover {
                background: #ff4444;
              }
              
              button:disabled {
                background: #666;
                cursor: not-allowed;
              }
              
              .loading {
                text-align: center;
                padding: 40px;
                font-size: 1.2rem;
                color: #999;
              }
              
              .error {
                background: rgba(255, 0, 0, 0.1);
                border: 2px solid #ff3333;
                padding: 20px;
                border-radius: 8px;
                margin-top: 20px;
              }
              
              .results {
                margin-top: 40px;
                background: #2a2a2a;
                padding: 30px;
                border-radius: 12px;
                display: none;
              }
              
              .results.show {
                display: block;
              }
              
              .preview-card {
                background: #333;
                border: 1px solid #444;
                border-radius: 8px;
                overflow: hidden;
                margin-bottom: 30px;
              }
              
              .preview-image {
                width: 100%;
                max-width: 600px;
                height: auto;
                display: block;
              }
              
              .preview-content {
                padding: 20px;
              }
              
              .preview-title {
                font-size: 1.5rem;
                margin-bottom: 10px;
              }
              
              .preview-description {
                color: #ccc;
                line-height: 1.6;
                margin-bottom: 10px;
              }
              
              .preview-url {
                color: #999;
                font-size: 0.9rem;
              }
              
              .meta-data {
                margin-top: 30px;
              }
              
              .meta-title {
                font-size: 1.3rem;
                margin-bottom: 20px;
                color: #ff3333;
              }
              
              .meta-table {
                width: 100%;
                border-collapse: collapse;
              }
              
              .meta-table td {
                padding: 12px;
                border-bottom: 1px solid #444;
                vertical-align: top;
              }
              
              .meta-table td:first-child {
                font-weight: bold;
                color: #ff3333;
                width: 200px;
              }
              
              .meta-table td:last-child {
                color: #ccc;
                word-break: break-all;
              }
              
              code {
                background: #1a1a1a;
                padding: 2px 6px;
                border-radius: 4px;
                font-family: 'Berkeley Mono', monospace;
              }
            </style>
          </head>
          <body>
            <div class="container">
              <h1>OpenGraph Preview Tool</h1>
              <p class="subtitle">Test how your pages will appear when shared on social media</p>
              
              <div class="form-group">
                <label for="url">Enter URL to preview:</label>
                <input type="url" id="url" placeholder="http://100.104.170.10:8005/2025/camps" value="">
                <button onclick="fetchOGData()" id="fetchBtn">Fetch OpenGraph Data</button>
              </div>
              
              <div id="loading" class="loading" style="display: none;">
                Fetching OpenGraph data...
              </div>
              
              <div id="error" class="error" style="display: none;"></div>
              
              <div id="results" class="results">
                <div class="preview-card">
                  <img id="previewImage" class="preview-image" style="display: none;">
                  <div class="preview-content">
                    <h2 id="previewTitle" class="preview-title"></h2>
                    <p id="previewDescription" class="preview-description"></p>
                    <p id="previewUrl" class="preview-url"></p>
                  </div>
                </div>
                
                <div class="meta-data">
                  <h3 class="meta-title">All OpenGraph Tags Found:</h3>
                  <table class="meta-table" id="metaTable">
                  </table>
                </div>
              </div>
            </div>
            
            <script>
              async function fetchOGData() {
                const urlInput = document.getElementById('url');
                const url = urlInput.value.trim();
                
                if (!url) {
                  showError('Please enter a URL');
                  return;
                }
                
                // UI states
                const loading = document.getElementById('loading');
                const error = document.getElementById('error');
                const results = document.getElementById('results');
                const fetchBtn = document.getElementById('fetchBtn');
                
                // Reset states
                loading.style.display = 'block';
                error.style.display = 'none';
                results.classList.remove('show');
                fetchBtn.disabled = true;
                
                try {
                  const response = await fetch('/api/v1/opengraph/fetch', {
                    method: 'POST',
                    headers: {
                      'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({ url })
                  });
                  
                  const data = await response.json();
                  
                  if (!response.ok) {
                    throw new Error(data.error || 'Failed to fetch OpenGraph data');
                  }
                  
                  displayResults(data);
                } catch (err) {
                  showError(err.message);
                } finally {
                  loading.style.display = 'none';
                  fetchBtn.disabled = false;
                }
              }
              
              function showError(message) {
                const error = document.getElementById('error');
                error.textContent = 'Error: ' + message;
                error.style.display = 'block';
              }
              
              function displayResults(data) {
                const results = document.getElementById('results');
                
                // Update preview card
                const title = data.title || data.twitter_title || 'No title found';
                const description = data.description || data.twitter_description || 'No description found';
                const image = data.image || data.twitter_image;
                const url = data.url || '';
                
                document.getElementById('previewTitle').textContent = title;
                document.getElementById('previewDescription').textContent = description;
                document.getElementById('previewUrl').textContent = url;
                
                const previewImage = document.getElementById('previewImage');
                if (image) {
                  previewImage.src = image;
                  previewImage.style.display = 'block';
                  previewImage.onerror = () => {
                    previewImage.style.display = 'none';
                  };
                } else {
                  previewImage.style.display = 'none';
                }
                
                // Update meta table
                const metaTable = document.getElementById('metaTable');
                metaTable.innerHTML = '';
                
                Object.entries(data).forEach(([key, value]) => {
                  if (key === 'url') return; // Skip the URL we added
                  
                  const row = metaTable.insertRow();
                  const keyCell = row.insertCell(0);
                  const valueCell = row.insertCell(1);
                  
                  keyCell.textContent = key;
                  
                  if (key.includes('image') && value && value.startsWith('http')) {
                    valueCell.innerHTML = `<a href="\${value}" target="_blank" style="color: #ff3333;">\${value}</a>`;
                  } else {
                    valueCell.textContent = value;
                  }
                });
                
                results.classList.add('show');
              }
              
              // Allow Enter key to submit
              document.getElementById('url').addEventListener('keypress', (e) => {
                if (e.key === 'Enter') {
                  fetchOGData();
                }
              });
            </script>
          </body>
          </html>
        HTML
      end
      
      def wrapper_styles
        <<~CSS
          /* Page container for test view */
          html, body.test-view {
            width: 100%;
            height: 100vh;
            margin: 0;
            padding: 0;
            background: #333333;
            display: flex;
            align-items: center;
            justify-content: center;
          }
          
          .opengraph-container {
            width: 1200px;
            height: 630px;
            position: relative;
            box-shadow: 0 10px 40px rgba(0, 0, 0, 0.5);
          }
        CSS
      end
      
      def html_template(title, subtitle, year, fonts_base_url, logo_url, bg_url, include_wrapper = true)
        <<~HTML
          <!DOCTYPE html>
          <html>
          <head>
            <style>
              #{include_wrapper ? wrapper_styles : ''}
              
              @font-face {
                font-family: 'Berkeley Mono';
                font-style: normal;
                font-weight: 400;
                src: url('#{fonts_base_url}/BerkeleyMono-Regular.woff2') format('woff2'),
                     url('#{fonts_base_url}/BerkeleyMono-Regular.woff') format('woff');
              }
              
              @font-face {
                font-family: 'Berkeley Mono';
                font-style: normal;
                font-weight: 700;
                src: url('#{fonts_base_url}/BerkeleyMono-Bold.woff2') format('woff2'),
                     url('#{fonts_base_url}/BerkeleyMono-Bold.woff') format('woff');
              }
              
              * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
              }
              
              .opengraph-content {
                width: 1200px;
                height: 630px;
                position: relative;
                overflow: hidden;
                background: #000000;
                color: #FFFFFF;
                font-family: 'Berkeley Mono', monospace;
              }
              
              .bg-container {
                position: absolute;
                top: 0;
                left: 0;
                width: 100%;
                height: 100%;
                overflow: hidden;
              }
              
              .bg-image {
                width: 150px;
                height: 100px;
              }
              
              .content-overlay {
                position: absolute;
                top: 0;
                left: 0;
                width: 100%;
                height: 100%;
                display: flex;
                align-items: center;
                justify-content: space-between;
                padding: 80px;
                box-sizing: border-box;
              }
              
              .content {
                flex: 1;
                display: flex;
                flex-direction: column;
                justify-content: center;
                max-width: 700px;
              }
              
              .logo {
                width: 300px;
                height: 300px;
                opacity: 0.9;
                flex-shrink: 0;
              }
              
              .title {
                font-size: 72px;
                font-weight: 700;
                line-height: 1.1;
                margin-bottom: 24px;
                letter-spacing: -0.02em;
              }
              
              .subtitle {
                font-size: 32px;
                font-weight: 400;
                line-height: 1.3;
                opacity: 0.8;
                margin-bottom: 40px;
              }
              
              .meta {
                font-size: 24px;
                opacity: 0.6;
                display: flex;
                align-items: center;
                gap: 20px;
              }
              
              .divider {
                width: 2px;
                height: 24px;
                background: #FFFFFF;
                opacity: 0.3;
              }
            </style>
          </head>
          <body#{include_wrapper ? ' class="test-view"' : ''}>
            #{include_wrapper ? '<div class="opengraph-container">' : ''}
              <div class="opengraph-content">
                
                <div class="content-overlay">
                  <div class="content">
                    <h1 class="title">#{ERB::Util.html_escape(title)}</h1>
                    #{subtitle.present? ? "<p class='subtitle'>#{ERB::Util.html_escape(subtitle)}</p>" : ''}
                    <div class="meta">
                      <span>40.7864° N, 119.2065° W</span>
                    </div>
                  </div>
                  
                  <img class="logo" src="#{logo_url}" alt="OKNOTOK">
                </div>
              </div>
            #{include_wrapper ? '</div>' : ''}
          </body>
          </html>
        HTML
      end
      
    end
  end
end