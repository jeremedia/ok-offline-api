module Api
  module V1
    class TilesController < ApplicationController
      
      # Serve the pre-packaged tile ZIP file
      def package
        package_path = Rails.root.join('public', 'tiles', 'package.zip')
        
        # Fall back to test package if main package doesn't exist
        unless File.exist?(package_path)
          test_path = Rails.root.join('public', 'tiles', 'test-package.zip')
          package_path = test_path if File.exist?(test_path)
        end
        
        if File.exist?(package_path)
          # Set cache headers for efficient caching
          response.headers['Cache-Control'] = 'public, max-age=86400' # Cache for 24 hours
          response.headers['ETag'] = Digest::MD5.file(package_path).hexdigest
          
          # Handle conditional requests
          if request.headers['If-None-Match'] == response.headers['ETag']
            head :not_modified
            return
          end
          
          # Send the file
          send_file package_path,
            type: 'application/zip',
            disposition: 'attachment',
            filename: 'brc-tiles.zip',
            x_sendfile: true # Use nginx/apache acceleration if available
        else
          render json: { 
            error: 'Tile package not found',
            message: 'Please run: rails tiles:create_package'
          }, status: :not_found
        end
      end
    end
  end
end