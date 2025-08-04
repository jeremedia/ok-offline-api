# frozen_string_literal: true

module Api
  module V1
    class ThemesController < Api::V1::BaseController
      before_action :ensure_development_environment
      
      # GET /api/v1/themes
      def index
        render json: { themes: load_themes }
      end
      
      # POST /api/v1/themes
      def create
        themes = load_themes
        # Handle both direct params and wrapped params
        theme_data = params[:theme] || params
        theme_id = theme_data[:id] || generate_theme_id(theme_data[:name])
        
        # Validate required fields
        unless theme_data[:name] && theme_data[:colors]
          render json: { error: 'Name and colors are required' }, status: :unprocessable_entity
          return
        end
        
        themes[theme_id] = build_theme(theme_id)
        
        save_themes(themes)
        render json: { 
          theme: themes[theme_id], 
          message: 'Theme saved successfully',
          total_themes: themes.keys.length
        }
      rescue StandardError => e
        render json: { error: "Failed to save theme: #{e.message}" }, status: :internal_server_error
      end
      
      # PUT/PATCH /api/v1/themes/:id
      def update
        themes = load_themes
        theme_id = params[:id]
        
        unless themes[theme_id]
          render json: { error: 'Theme not found' }, status: :not_found
          return
        end
        
        # Handle both direct params and wrapped params
        theme_data = params[:theme] || params
        
        # Validate required fields
        unless theme_data[:name] && theme_data[:colors]
          render json: { error: 'Name and colors are required' }, status: :unprocessable_entity
          return
        end
        
        themes[theme_id] = build_theme(theme_id)
        save_themes(themes)
        
        render json: { 
          theme: themes[theme_id], 
          message: 'Theme updated successfully' 
        }
      rescue StandardError => e
        render json: { error: "Failed to update theme: #{e.message}" }, status: :internal_server_error
      end
      
      # DELETE /api/v1/themes/:id
      def destroy
        themes = load_themes
        theme_id = params[:id]
        
        # Prevent deletion of factory themes
        factory_themes = %w[oknotok sparkle khaki mush]
        if factory_themes.include?(theme_id)
          render json: { error: 'Cannot delete factory themes' }, status: :forbidden
          return
        end
        
        if themes.delete(theme_id)
          save_themes(themes)
          render json: { message: 'Theme deleted successfully' }
        else
          render json: { error: 'Theme not found' }, status: :not_found
        end
      end
      
      private
      
      def ensure_development_environment
        unless Rails.env.development?
          render json: { 
            error: 'This endpoint is only available in development environment' 
          }, status: :forbidden
        end
      end
      
      def themes_file_path
        # Primary path - always check first
        primary_path = Rails.root.join("..", "frontend", "public", "data", "themes.json")
        return primary_path if File.exist?(primary_path)
        
        # Development worktree fallback
        if Rails.env.development?
          # Check for any frontend-* worktree directories
          worktree_paths = Dir.glob(Rails.root.join("..", "frontend-*", "public", "data", "themes.json"))
          if worktree_paths.any?
            Rails.logger.info "Using worktree themes.json: #{worktree_paths.first}"
            return Pathname.new(worktree_paths.first)
          end
        end
        
        # If no themes.json found, return primary path (will fail with clear error)
        primary_path
      end
      
      def load_themes
        file_content = File.read(themes_file_path)
        JSON.parse(file_content)['themes'] || {}
      rescue JSON::ParserError => e
        Rails.logger.error "Failed to parse themes.json: #{e.message}"
        {}
      end
      
      def save_themes(themes)
        # Create backup before saving
        backup_path = themes_file_path.to_s + '.backup'
        FileUtils.copy(themes_file_path, backup_path) if File.exist?(themes_file_path)
        
        # Write formatted JSON
        File.write(themes_file_path, JSON.pretty_generate({ themes: themes }))
      end
      
      def generate_theme_id(name)
        name.downcase.gsub(/[^a-z0-9]/, '-').gsub(/-+/, '-').gsub(/^-|-$/, '')
      end
      
      def build_theme(theme_id)
        # Handle both direct params and wrapped params
        theme_data = params[:theme] || params
        
        # Extract colors properly, handling ActionController::Parameters
        colors = if theme_data[:colors].is_a?(ActionController::Parameters)
          theme_data[:colors].to_unsafe_h.stringify_keys
        else
          theme_data[:colors].to_h.stringify_keys
        end
        
        {
          'id' => theme_id,
          'name' => theme_data[:name],
          'description' => theme_data[:description] || '',
          'colors' => colors
        }
      end
      
      def theme_params
        if params[:theme]
          params.require(:theme).permit(:id, :name, :description, colors: {})
        else
          params.permit(:id, :name, :description, colors: {})
        end
      end
    end
  end
end