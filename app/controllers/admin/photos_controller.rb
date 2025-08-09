module Admin
  class PhotosController < Admin::BaseController
    before_action :set_infrastructure
    before_action :set_photo, only: [:edit, :update, :destroy, :set_as_hero]
    
    def index
      @photos = @infrastructure.photos.includes(:blob_attachment)
      @photos_by_type = @photos.group_by(&:photo_type)
    end
    
    def new
      @photo = @infrastructure.photos.build
    end
    
    def create
      @photo = @infrastructure.photos.build(photo_params)
      
      if params[:photo][:image].present?
        # Handle file upload
        uploaded_file = params[:photo][:image]
        @photo.image.attach(uploaded_file)
        
        # Extract dimensions if possible
        if @photo.image.analyzed?
          @photo.width = @photo.image.metadata[:width]
          @photo.height = @photo.image.metadata[:height]
        end
      end
      
      if @photo.save
        redirect_to admin_infrastructure_photos_path(@infrastructure), notice: 'Photo uploaded successfully.'
      else
        render :new
      end
    end
    
    def edit
    end
    
    def update
      if @photo.update(photo_params)
        # Handle new image upload if provided
        if params[:photo][:image].present?
          @photo.image.attach(params[:photo][:image])
          if @photo.image.analyzed?
            @photo.update(
              width: @photo.image.metadata[:width],
              height: @photo.image.metadata[:height]
            )
          end
        end
        
        redirect_to admin_infrastructure_photos_path(@infrastructure), notice: 'Photo updated successfully.'
      else
        render :edit
      end
    end
    
    def destroy
      # Remove from hero if this was the hero photo
      @infrastructure.update(hero_photo: nil) if @infrastructure.hero_photo == @photo
      
      @photo.destroy
      redirect_to admin_infrastructure_photos_path(@infrastructure), notice: 'Photo removed successfully.'
    end
    
    def set_as_hero
      @infrastructure.update(hero_photo: @photo)
      redirect_to admin_infrastructure_photos_path(@infrastructure), notice: 'Hero photo updated.'
    end
    
    # Bulk upload endpoint for multiple photos
    def bulk_upload
      uploaded_count = 0
      errors = []
      
      params[:photos].each do |photo_data|
        photo = @infrastructure.photos.build(
          title: photo_data[:title],
          photo_type: photo_data[:photo_type] || 'gallery',
          year: photo_data[:year] || Date.current.year
        )
        
        if photo_data[:image].present?
          photo.image.attach(photo_data[:image])
          
          if photo.save
            uploaded_count += 1
          else
            errors << "#{photo_data[:title]}: #{photo.errors.full_messages.join(', ')}"
          end
        end
      end
      
      flash[:notice] = "#{uploaded_count} photos uploaded successfully."
      flash[:alert] = errors.join('; ') if errors.any?
      
      redirect_to admin_infrastructure_photos_path(@infrastructure)
    end
    
    private
    
    def set_infrastructure
      @infrastructure = Infrastructure.find_by!(uid: params[:infrastructure_id])
    end
    
    def set_photo
      @photo = @infrastructure.photos.find(params[:id])
    end
    
    def photo_params
      params.require(:infrastructure_photo).permit(
        :title, :caption, :year, :theme_name, :photographer_credit,
        :photo_type, :position, :width, :height, :cdn_url
      )
    end
  end
end