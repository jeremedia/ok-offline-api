class Api::V1::CampScheduleItemsController < Api::V1::BaseController
  before_action :find_theme_camp
  before_action :find_schedule_item, only: [:show, :update, :destroy, :assign_members, :unassign_member]
  
  # GET /api/v1/theme_camps/:camp_slug/schedule_items
  def index
    @schedule_items = @theme_camp.camp_schedule_items.includes(:responsible_person, :team_members)
    
    # Apply filters
    @schedule_items = @schedule_items.by_category(params[:category]) if params[:category].present?
    @schedule_items = @schedule_items.active unless params[:include_inactive] == 'true'
    @schedule_items = @schedule_items.search(params[:q]) if params[:q].present?
    
    # Apply date filtering
    if params[:start_date].present? && params[:end_date].present?
      start_date = Date.parse(params[:start_date])
      end_date = Date.parse(params[:end_date])
      @schedule_items = @schedule_items.for_date_range(start_date, end_date)
    elsif params[:date].present?
      date = Date.parse(params[:date])
      @schedule_items = @schedule_items.for_date_range(date, date)
    end
    
    # Default ordering
    @schedule_items = @schedule_items.chronological
    
    render json: serialize_schedule_items(@schedule_items)
  end
  
  # GET /api/v1/theme_camps/:camp_slug/schedule_items/:id
  def show
    render json: serialize_schedule_item(@schedule_item, include_assignments: true)
  end
  
  # POST /api/v1/theme_camps/:camp_slug/schedule_items
  def create
    @schedule_item = @theme_camp.camp_schedule_items.build(schedule_item_params)
    
    if @schedule_item.save
      # Assign team members if provided
      assign_team_members if params[:team_member_ids].present?
      
      render json: serialize_schedule_item(@schedule_item, include_assignments: true), status: :created
    else
      render json: { 
        error: 'Failed to create schedule item', 
        details: @schedule_item.errors 
      }, status: :unprocessable_entity
    end
  end
  
  # PUT /api/v1/theme_camps/:camp_slug/schedule_items/:id
  def update
    if @schedule_item.update(schedule_item_params)
      # Update team member assignments if provided
      if params[:team_member_ids].present?
        @schedule_item.camp_schedule_assignments.destroy_all
        assign_team_members
      end
      
      render json: serialize_schedule_item(@schedule_item, include_assignments: true)
    else
      render json: { 
        error: 'Failed to update schedule item', 
        details: @schedule_item.errors 
      }, status: :unprocessable_entity
    end
  end
  
  # DELETE /api/v1/theme_camps/:camp_slug/schedule_items/:id
  def destroy
    if @schedule_item.destroy
      render json: { message: 'Schedule item deleted successfully' }
    else
      render json: { 
        error: 'Failed to delete schedule item', 
        details: @schedule_item.errors 
      }, status: :unprocessable_entity
    end
  end
  
  # POST /api/v1/theme_camps/:camp_slug/schedule_items/:id/assign_members
  def assign_members
    team_member_ids = params[:team_member_ids] || []
    assignments = params[:assignments] || {} # Hash of member_id => notes
    
    # Clear existing assignments
    @schedule_item.camp_schedule_assignments.destroy_all
    
    # Create new assignments
    successful_assignments = 0
    team_member_ids.each do |member_id|
      member = @theme_camp.team_members.find_by(id: member_id)
      next unless member
      
      assignment = @schedule_item.camp_schedule_assignments.build(
        team_member: member,
        notes: assignments[member_id.to_s]
      )
      
      successful_assignments += 1 if assignment.save
    end
    
    render json: {
      message: "#{successful_assignments} team members assigned successfully",
      schedule_item: serialize_schedule_item(@schedule_item, include_assignments: true)
    }
  end
  
  # DELETE /api/v1/theme_camps/:camp_slug/schedule_items/:id/unassign_member/:member_id
  def unassign_member
    member_id = params[:member_id]
    assignment = @schedule_item.camp_schedule_assignments.find_by(team_member_id: member_id)
    
    if assignment&.destroy
      render json: { 
        message: 'Team member unassigned successfully',
        schedule_item: serialize_schedule_item(@schedule_item, include_assignments: true)
      }
    else
      render json: { error: 'Assignment not found or could not be removed' }, status: :not_found
    end
  end
  
  # GET /api/v1/theme_camps/:camp_slug/schedule_items/conflicts
  def conflicts
    start_datetime = DateTime.parse(params[:start_datetime]) if params[:start_datetime]
    end_datetime = DateTime.parse(params[:end_datetime]) if params[:end_datetime]
    team_member_ids = params[:team_member_ids] || []
    
    unless start_datetime && end_datetime && team_member_ids.any?
      render json: { error: 'start_datetime, end_datetime, and team_member_ids are required' }, status: :bad_request
      return
    end
    
    conflicts = []
    team_member_ids.each do |member_id|
      member = @theme_camp.team_members.find_by(id: member_id)
      next unless member
      
      member_conflicts = member.schedule_conflicts_for(start_datetime, end_datetime)
      conflicts << {
        team_member: serialize_team_member(member),
        conflicts: serialize_schedule_items(member_conflicts)
      } if member_conflicts.any?
    end
    
    render json: { conflicts: conflicts }
  end
  
  private
  
  def find_theme_camp
    @theme_camp = ThemeCamp.friendly.find(params[:camp_slug])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Camp not found' }, status: :not_found
  end
  
  def find_schedule_item
    @schedule_item = @theme_camp.camp_schedule_items.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Schedule item not found' }, status: :not_found
  end
  
  def schedule_item_params
    params.require(:camp_schedule_item).permit(
      :title, :description, :start_datetime, :end_datetime, :location,
      :required_supplies, :notes, :category, :status, :responsible_person_id,
      :api_event_uid
    )
  end
  
  def assign_team_members
    team_member_ids = params[:team_member_ids] || []
    assignments = params[:assignments] || {}
    
    team_member_ids.each do |member_id|
      member = @theme_camp.team_members.find_by(id: member_id)
      next unless member
      
      @schedule_item.camp_schedule_assignments.create(
        team_member: member,
        notes: assignments[member_id.to_s]
      )
    end
  end
  
  def serialize_schedule_item(item, include_assignments: false)
    result = {
      id: item.id,
      title: item.title,
      description: item.description,
      start_datetime: item.start_datetime,
      end_datetime: item.end_datetime,
      location: item.location,
      required_supplies: item.required_supplies,
      notes: item.notes,
      category: item.category,
      category_display: item.category_display,
      status: item.status,
      status_display: item.status_display,
      api_event_uid: item.api_event_uid,
      duration_minutes: item.duration_minutes,
      duration_hours: item.duration_hours,
      is_current: item.is_current?,
      is_upcoming: item.is_upcoming?,
      is_past: item.is_past?,
      responsible_person: item.responsible_person ? serialize_team_member(item.responsible_person) : nil,
      created_at: item.created_at,
      updated_at: item.updated_at
    }
    
    if include_assignments
      result[:assignments] = item.camp_schedule_assignments.includes(:team_member).map do |assignment|
        {
          id: assignment.id,
          team_member: serialize_team_member(assignment.team_member),
          notes: assignment.notes
        }
      end
    end
    
    result
  end
  
  def serialize_schedule_items(items)
    items.includes(:responsible_person, :team_members).map { |item| serialize_schedule_item(item) }
  end
  
  def serialize_team_member(member)
    {
      id: member.id,
      first_name: member.first_name,
      last_name: member.last_name,
      playa_name: member.playa_name,
      full_name: member.full_name,
      display_name: member.display_name,
      role: member.role
    }
  end
end