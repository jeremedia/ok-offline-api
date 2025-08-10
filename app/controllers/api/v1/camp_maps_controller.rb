class Api::V1::CampMapsController < ApplicationController
  before_action :set_theme_camp
  before_action :set_camp_map, only: [:show, :update, :destroy]
  
  # GET /api/v1/theme_camps/:theme_camp_id/map
  def show
    if @camp_map
      render json: @camp_map.as_json(
        include: { 
          map_placements: { 
            include: [:gltf_model, :assigned_to] 
          } 
        }
      )
    else
      render json: { message: 'No map configured for this camp' }, status: :not_found
    end
  end
  
  # POST /api/v1/theme_camps/:theme_camp_id/map
  def create
    @camp_map = @theme_camp.build_camp_map(camp_map_params)
    
    if @camp_map.save
      render json: @camp_map, status: :created
    else
      render json: { errors: @camp_map.errors }, status: :unprocessable_entity
    end
  end
  
  # PATCH/PUT /api/v1/theme_camps/:theme_camp_id/map
  def update
    if @camp_map.update(camp_map_params)
      render json: @camp_map
    else
      render json: { errors: @camp_map.errors }, status: :unprocessable_entity
    end
  end
  
  # DELETE /api/v1/theme_camps/:theme_camp_id/map
  def destroy
    @camp_map.destroy
    head :no_content
  end
  
  # GET /api/v1/theme_camps/:theme_camp_id/map/stats
  def stats
    if @camp_map
      stats = {
        total_area: @camp_map.total_area,
        available_space: @camp_map.available_space,
        placement_density: @camp_map.placement_density,
        total_placements: @camp_map.map_placements.count,
        assigned_placements: @camp_map.map_placements.assigned.count,
        unassigned_placements: @camp_map.map_placements.unassigned.count
      }
      render json: stats
    else
      render json: { error: 'No map configured' }, status: :not_found
    end
  end
  
  # POST /api/v1/theme_camps/:theme_camp_id/map/placements
  def add_placement
    @placement = @camp_map.map_placements.build(placement_params)
    
    if @placement.save
      render json: @placement, status: :created
    else
      render json: { errors: @placement.errors }, status: :unprocessable_entity
    end
  end
  
  private
  
  def set_theme_camp
    @theme_camp = ThemeCamp.friendly.find(params[:theme_camp_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Theme camp not found' }, status: :not_found
  end
  
  def set_camp_map
    @camp_map = @theme_camp.camp_map
  end
  
  def camp_map_params
    params.require(:camp_map).permit(
      :total_width, :total_depth, :bm_address, :gps_latitude, :gps_longitude,
      :scale_factor, :orientation, :map_image
    )
  end
  
  def placement_params
    params.require(:map_placement).permit(
      :placement_type, :name, :description, :x_position, :y_position,
      :rotation, :width, :height, :gltf_model_id, :assigned_to_id
    )
  end
end
