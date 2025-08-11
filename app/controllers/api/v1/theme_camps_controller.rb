class Api::V1::ThemeCampsController < ApplicationController
  before_action :set_theme_camp, only: [:show, :update, :destroy]
  
  # GET /api/v1/theme_camps
  def index
    @theme_camps = ThemeCamp.all.order(:name)
    render json: @theme_camps.as_json(
      include: {
        team_members: { only: [:id, :first_name, :last_name, :playa_name, :role, :email] },
        camp_map: { only: [:id, :total_width, :total_depth, :bm_address] }
      }
    )
  end
  
  # GET /api/v1/theme_camps/:slug
  def show
    render json: @theme_camp.as_json(
      include: {
        team_members: { 
          include: { personal_space: { only: [:id, :space_type, :width, :depth, :height, :is_confirmed] } }
        },
        camp_map: { 
          include: { map_placements: { include: :gltf_model } }
        }
      }
    )
  end
  
  # POST /api/v1/theme_camps
  def create
    @theme_camp = ThemeCamp.new(theme_camp_params)
    
    if @theme_camp.save
      render json: @theme_camp, status: :created
    else
      render json: { errors: @theme_camp.errors }, status: :unprocessable_entity
    end
  end
  
  # PATCH/PUT /api/v1/theme_camps/:slug
  def update
    if @theme_camp.update(theme_camp_params)
      # Return the same detailed format as the show action
      render json: @theme_camp.as_json(
        include: {
          team_members: { 
            include: { personal_space: { only: [:id, :space_type, :width, :depth, :height, :is_confirmed] } }
          },
          camp_map: { 
            include: { map_placements: { include: :gltf_model } }
          }
        }
      )
    else
      render json: { errors: @theme_camp.errors }, status: :unprocessable_entity
    end
  end
  
  # DELETE /api/v1/theme_camps/:slug
  def destroy
    @theme_camp.destroy
    head :no_content
  end
  
  # GET /api/v1/theme_camps/:slug/team
  def team
    @theme_camp = ThemeCamp.friendly.find(params[:slug])
    render json: @theme_camp.team_members.as_json(
      include: { personal_space: { only: [:space_type, :width, :depth, :is_confirmed] } }
    )
  end
  
  # GET /api/v1/theme_camps/:slug/map
  def map
    @theme_camp = ThemeCamp.friendly.find(params[:slug])
    render json: @theme_camp.camp_map&.as_json(
      include: { map_placements: { include: :gltf_model } }
    )
  end
  
  private
  
  def set_theme_camp
    @theme_camp = ThemeCamp.friendly.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Theme camp not found' }, status: :not_found
  end
  
  def theme_camp_params
    params.require(:theme_camp).permit(
      :name, :slug, :year, :description, :website, :facebook,
      :camp_type, :expected_population, :bm_address, :is_active
    )
  end
end
