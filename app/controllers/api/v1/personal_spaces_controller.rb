class Api::V1::PersonalSpacesController < ApplicationController
  before_action :set_theme_camp
  before_action :set_team_member
  before_action :set_personal_space, only: [:show, :update, :destroy]
  
  # GET /api/v1/theme_camps/:theme_camp_id/team_members/:team_member_id/personal_space
  def show
    if @personal_space
      render json: @personal_space.as_json(include: :gltf_model)
    else
      render json: { message: 'No personal space assigned' }, status: :not_found
    end
  end
  
  # POST /api/v1/theme_camps/:theme_camp_id/team_members/:team_member_id/personal_space
  def create
    @personal_space = @team_member.build_personal_space(personal_space_params)
    
    if @personal_space.save
      render json: @personal_space, status: :created
    else
      render json: { errors: @personal_space.errors }, status: :unprocessable_entity
    end
  end
  
  # PATCH/PUT /api/v1/theme_camps/:theme_camp_id/team_members/:team_member_id/personal_space
  def update
    if @personal_space.update(personal_space_params)
      render json: @personal_space
    else
      render json: { errors: @personal_space.errors }, status: :unprocessable_entity
    end
  end
  
  # DELETE /api/v1/theme_camps/:theme_camp_id/team_members/:team_member_id/personal_space
  def destroy
    @personal_space.destroy
    head :no_content
  end
  
  private
  
  def set_theme_camp
    @theme_camp = ThemeCamp.friendly.find(params[:theme_camp_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Theme camp not found' }, status: :not_found
  end
  
  def set_team_member
    @team_member = @theme_camp.team_members.find(params[:team_member_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Team member not found' }, status: :not_found
  end
  
  def set_personal_space
    @personal_space = @team_member.personal_space
  end
  
  def personal_space_params
    params.require(:personal_space).permit(
      :space_type, :width, :depth, :height, :needs_power, :power_draw,
      :special_requirements, :is_confirmed, :gltf_model_id
    )
  end
end
