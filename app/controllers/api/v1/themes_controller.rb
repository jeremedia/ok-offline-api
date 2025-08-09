# frozen_string_literal: true

module Api
  module V1
    class ThemesController < Api::V1::BaseController
      before_action :set_theme, only: [:show, :update, :destroy]
      
      # GET /api/v1/themes
      def index
        # Cache the theme list for 1 hour
        @themes = Rails.cache.fetch(
          "themes/index/#{themes_cache_key}",
          expires_in: 1.hour
        ) do
          themes_hash = {}
          Theme.active.ordered.each do |theme|
            themes_hash[theme.theme_id] = theme.to_theme_format
          end
          themes_hash
        end
        
        render json: { themes: @themes }
      end
      
      # GET /api/v1/themes/:id
      def show
        theme_data = Rails.cache.fetch(
          "themes/#{@theme.id}/#{@theme.updated_at.to_i}",
          expires_in: 1.hour
        ) do
          @theme.to_theme_format
        end
        
        render json: theme_data
      end
      
      # POST /api/v1/themes
      def create
        @theme = Theme.new(theme_params)
        
        if @theme.save
          clear_themes_cache
          render json: { 
            theme: @theme.to_theme_format, 
            message: 'Theme created successfully' 
          }, status: :created
        else
          render json: { errors: @theme.errors }, status: :unprocessable_entity
        end
      end
      
      # PUT/PATCH /api/v1/themes/:id
      def update
        if @theme.update(theme_params)
          clear_themes_cache
          render json: { 
            theme: @theme.to_theme_format, 
            message: 'Theme updated successfully' 
          }
        else
          render json: { errors: @theme.errors }, status: :unprocessable_entity
        end
      end
      
      # DELETE /api/v1/themes/:id
      def destroy
        # Prevent deletion of factory themes
        factory_themes = %w[oknotok sparkle khaki mush]
        if factory_themes.include?(@theme.theme_id)
          render json: { error: 'Cannot delete factory themes' }, status: :forbidden
          return
        end
        
        @theme.destroy
        clear_themes_cache
        render json: { message: 'Theme deleted successfully' }
      end
      
      private
      
      def set_theme
        @theme = Theme.find_by!(theme_id: params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Theme not found' }, status: :not_found
      end
      
      def theme_params
        # Handle both direct params and wrapped params
        theme_data = params[:theme] || params
        
        processed_params = {}
        processed_params[:theme_id] = theme_data[:id] || generate_theme_id(theme_data[:name])
        processed_params[:name] = theme_data[:name]
        processed_params[:description] = theme_data[:description]
        processed_params[:colors] = process_colors(theme_data[:colors])
        processed_params[:typography] = process_typography(theme_data[:typography])
        processed_params[:position] = theme_data[:position] if theme_data[:position]
        processed_params[:active] = theme_data.key?(:active) ? theme_data[:active] : true
        
        processed_params
      end
      
      def process_colors(colors_param)
        return {} unless colors_param
        
        if colors_param.is_a?(ActionController::Parameters)
          colors_param.to_unsafe_h.stringify_keys
        else
          colors_param.to_h.stringify_keys
        end
      end
      
      def process_typography(typography_param)
        return nil unless typography_param
        
        if typography_param.is_a?(ActionController::Parameters)
          typography_param.to_unsafe_h.stringify_keys
        else
          typography_param.to_h.stringify_keys
        end
      end
      
      def generate_theme_id(name)
        return nil unless name
        name.downcase.gsub(/[^a-z0-9]/, '-').gsub(/-+/, '-').gsub(/^-|-$/, '')
      end
      
      def themes_cache_key
        # Include the latest theme update time in cache key
        latest_update = Theme.maximum(:updated_at)
        "v1/#{latest_update&.to_i}"
      end
      
      def clear_themes_cache
        Rails.cache.delete_matched("themes/*")
      end
    end
  end
end