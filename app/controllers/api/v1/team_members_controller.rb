class Api::V1::TeamMembersController < ApplicationController
  before_action :set_theme_camp
  before_action :set_team_member, only: [:show, :update, :destroy]
  
  # GET /api/v1/theme_camps/:theme_camp_id/team_members
  def index
    @team_members = @theme_camp.team_members.includes(:personal_space)
    render json: @team_members.as_json(
      include: { personal_space: { only: [:id, :space_type, :width, :depth, :height, :is_confirmed] } }
    )
  end
  
  # GET /api/v1/theme_camps/:theme_camp_id/team_members/:id
  def show
    render json: @team_member.as_json(
      include: { personal_space: true }
    )
  end
  
  # POST /api/v1/theme_camps/:theme_camp_id/team_members
  def create
    @team_member = @theme_camp.team_members.build(team_member_params)
    
    if @team_member.save
      render json: @team_member, status: :created
    else
      render json: { errors: @team_member.errors }, status: :unprocessable_entity
    end
  end
  
  # PATCH/PUT /api/v1/theme_camps/:theme_camp_id/team_members/:id
  def update
    if @team_member.update(team_member_params)
      render json: @team_member
    else
      render json: { errors: @team_member.errors }, status: :unprocessable_entity
    end
  end
  
  # DELETE /api/v1/theme_camps/:theme_camp_id/team_members/:id
  def destroy
    @team_member.destroy
    head :no_content
  end
  
  private
  
  def set_theme_camp
    @theme_camp = ThemeCamp.friendly.find(params[:theme_camp_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Theme camp not found' }, status: :not_found
  end
  
  def set_team_member
    @team_member = @theme_camp.team_members.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Team member not found' }, status: :not_found
  end
  
  def team_member_params
    params.require(:team_member).permit(
      :first_name, :last_name, :playa_name, :email, :role, :phone, :skills,
      :arrival_date, :departure_date, :emergency_contact_name, :emergency_contact_phone,
      :dietary_restrictions, :is_verified, :photo
    )
  end
end
