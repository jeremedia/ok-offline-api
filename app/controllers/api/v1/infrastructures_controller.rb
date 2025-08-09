class Api::V1::InfrastructuresController < Api::V1::BaseController
  before_action :set_infrastructure, only: [:show]
  
  def index
    # Cache the entire infrastructure list
    @infrastructures = Rails.cache.fetch(
      "infrastructure/#{params[:year]}/index/#{index_cache_key}", 
      expires_in: 1.hour
    ) do
      Infrastructure
        .includes(:locations, :timeline_events, :facts, :links, :photos, :hero_photo)
        .active
        .for_year(params[:year] || Date.current.year)
        .ordered
        .map { |i| infrastructure_json(i) }
    end
    
    render json: { infrastructure: @infrastructures }
  end
  
  def show
    # Cache individual infrastructure items
    json_data = Rails.cache.fetch(
      "infrastructure/#{@infrastructure.id}/#{@infrastructure.updated_at.to_i}",
      expires_in: 1.hour
    ) do
      infrastructure_json(@infrastructure)
    end
    
    render json: json_data
  end
  
  private
  
  def set_infrastructure
    @infrastructure = Infrastructure
      .includes(:locations, :timeline_events, :facts, :links, :photos, :hero_photo)
      .find_by!(uid: params[:id])
  end
  
  def infrastructure_json(infrastructure)
    {
      id: infrastructure.uid,
      name: infrastructure.name,
      icon: infrastructure.icon,
      category: infrastructure.category,
      coordinates: infrastructure.coordinates,
      shortDescription: infrastructure.short_description,
      
      # Photo data
      heroPhoto: photo_json(infrastructure.hero_photo),
      photos: infrastructure.photos.map { |p| photo_json(p) },
      photosByYear: infrastructure.photos_by_year.transform_values { |photos|
        photos.map { |p| photo_json(p) }
      },
      
      # For Man/Temple - themed photos
      themedPhotos: infrastructure.uid.in?(['the-man', 'temple']) ? 
        infrastructure.themed_photos.transform_values { |photos|
          photos.map { |p| photo_json(p) }
        } : nil,
      
      # Rich content
      history: infrastructure.history,
      civicPurpose: infrastructure.civic_purpose,
      legalContext: infrastructure.legal_context,
      operations: infrastructure.operations,
      
      # Related data
      locations: infrastructure.locations.map { |loc| location_json(loc) },
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
      urls: photo.responsive_urls,
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
  
  def index_cache_key
    # Cache key includes latest update time
    latest = Infrastructure.maximum(:updated_at)
    "v1/#{latest&.to_i}/#{params[:category]}"
  end
end