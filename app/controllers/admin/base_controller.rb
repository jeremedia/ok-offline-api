module Admin
  class BaseController < ApplicationController
    # Ensure only development environment can access admin
    before_action :ensure_development_environment
    
    # Use admin layout for all admin controllers
    layout 'admin'
    
    # Skip CSRF protection for admin (development only)
    skip_before_action :verify_authenticity_token
    
    private
    
    def ensure_development_environment
      unless Rails.env.development?
        render json: { error: 'Admin interface is only available in development' }, status: :forbidden
      end
    end
  end
end