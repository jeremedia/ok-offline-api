module Admin
  class InfrastructuresController < Admin::BaseController
    before_action :set_infrastructure, only: [:show, :edit, :update, :destroy]
    
    def index
      @infrastructures = Infrastructure
        .includes(:locations, :timeline_events, :facts, :links, :photos)
        .ordered
      
      respond_to do |format|
        format.html
        format.json { render json: @infrastructures }
      end
    end
    
    def show
      respond_to do |format|
        format.html
        format.json { render json: infrastructure_json(@infrastructure) }
      end
    end
    
    def new
      @infrastructure = Infrastructure.new
      # Build default associations
      @infrastructure.locations.build
      @infrastructure.timeline_events.build
      @infrastructure.facts.build
      @infrastructure.links.build
    end
    
    def create
      @infrastructure = Infrastructure.new(infrastructure_params)
      
      if @infrastructure.save
        handle_photo_uploads
        redirect_to admin_infrastructure_path(@infrastructure), notice: 'Infrastructure was successfully created.'
      else
        render :new
      end
    end
    
    def edit
      # Ensure at least one of each association exists for the form
      @infrastructure.locations.build if @infrastructure.locations.empty?
      @infrastructure.timeline_events.build if @infrastructure.timeline_events.empty?
      @infrastructure.facts.build if @infrastructure.facts.empty?
      @infrastructure.links.build if @infrastructure.links.empty?
    end
    
    def update
      if @infrastructure.update(infrastructure_params)
        handle_photo_uploads
        redirect_to admin_infrastructure_path(@infrastructure), notice: 'Infrastructure was successfully updated.'
      else
        render :edit
      end
    end
    
    def destroy
      @infrastructure.destroy
      redirect_to admin_infrastructures_path, notice: 'Infrastructure was successfully deleted.'
    end
    
    private
    
    def set_infrastructure
      @infrastructure = Infrastructure.find_by!(uid: params[:id])
    end
    
    def infrastructure_params
      params.require(:infrastructure).permit(
        :name, :uid, :icon, :category, :short_description,
        :history, :civic_purpose, :legal_context, :operations,
        :latitude, :longitude, :address, :position, :active,
        :hero_photo_id,
        locations_attributes: [:id, :name, :latitude, :longitude, :address, :notes, :position, :_destroy],
        timeline_events_attributes: [:id, :year, :event, :position, :_destroy],
        facts_attributes: [:id, :content, :position, :_destroy],
        links_attributes: [:id, :title, :url, :position, :_destroy],
        photos_attributes: [:id, :title, :caption, :year, :theme_name, :photographer_credit, 
                          :photo_type, :position, :width, :height, :_destroy]
      )
    end
    
    def handle_photo_uploads
      # Handle hero image upload
      if params[:infrastructure][:hero_image].present?
        @infrastructure.hero_image.attach(params[:infrastructure][:hero_image])
        create_photo_record(@infrastructure.hero_image, 'hero')
      end
      
      # Handle gallery images upload
      if params[:infrastructure][:gallery_images].present?
        params[:infrastructure][:gallery_images].each do |image|
          @infrastructure.gallery_images.attach(image)
          create_photo_record(image, 'gallery')
        end
      end
    end
    
    def create_photo_record(attachment, photo_type)
      # Create InfrastructurePhoto record for the uploaded image
      photo = @infrastructure.photos.create!(
        photo_type: photo_type,
        title: attachment.filename.to_s,
        year: Date.current.year,
        active_storage_blob_id: attachment.blob.id
      )
      
      # Set as hero photo if it's a hero image
      @infrastructure.update(hero_photo: photo) if photo_type == 'hero'
    end
    
    def infrastructure_json(infrastructure)
      {
        id: infrastructure.uid,
        name: infrastructure.name,
        icon: infrastructure.icon,
        category: infrastructure.category,
        coordinates: infrastructure.coordinates,
        shortDescription: infrastructure.short_description,
        heroPhoto: photo_json(infrastructure.hero_photo),
        photos: infrastructure.photos.map { |p| photo_json(p) },
        history: infrastructure.history,
        civicPurpose: infrastructure.civic_purpose,
        legalContext: infrastructure.legal_context,
        operations: infrastructure.operations,
        locations: infrastructure.locations.map { |l| location_json(l) },
        timeline: infrastructure.timeline_events.map { |t| timeline_json(t) },
        didYouKnow: infrastructure.facts.pluck(:content),
        relatedLinks: infrastructure.links.map { |l| link_json(l) }
      }
    end
    
    def photo_json(photo)
      return nil unless photo
      
      {
        id: photo.id,
        title: photo.title,
        caption: photo.caption,
        year: photo.year,
        theme: photo.theme_name,
        photographer: photo.photographer_credit,
        type: photo.photo_type,
        dimensions: {
          width: photo.width,
          height: photo.height
        }
      }
    end
    
    def location_json(location)
      {
        name: location.name,
        coordinates: location.coordinates,
        address: location.address,
        notes: location.notes
      }
    end
    
    def timeline_json(timeline_event)
      {
        year: timeline_event.year,
        event: timeline_event.event
      }
    end
    
    def link_json(link)
      {
        title: link.title,
        url: link.url
      }
    end
  end
end