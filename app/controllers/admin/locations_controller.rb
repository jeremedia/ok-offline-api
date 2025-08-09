module Admin
  class LocationsController < Admin::BaseController
    before_action :set_infrastructure
    before_action :set_location, only: [:edit, :update, :destroy]
    
    def new
      @location = @infrastructure.locations.build
    end
    
    def create
      @location = @infrastructure.locations.build(location_params)
      
      if @location.save
        redirect_to admin_infrastructure_path(@infrastructure), notice: 'Location added successfully.'
      else
        render :new
      end
    end
    
    def edit
    end
    
    def update
      if @location.update(location_params)
        redirect_to admin_infrastructure_path(@infrastructure), notice: 'Location updated successfully.'
      else
        render :edit
      end
    end
    
    def destroy
      @location.destroy
      redirect_to admin_infrastructure_path(@infrastructure), notice: 'Location removed successfully.'
    end
    
    private
    
    def set_infrastructure
      @infrastructure = Infrastructure.find_by!(uid: params[:infrastructure_id])
    end
    
    def set_location
      @location = @infrastructure.locations.find(params[:id])
    end
    
    def location_params
      params.require(:infrastructure_location).permit(:name, :latitude, :longitude, :address, :notes, :position)
    end
  end
end