module Api
  module V1
    class BurningManController < ApplicationController
      # GET /api/v1/
      def index
        render json: {
          description: "OK-OFFLINE Burning Man API - Compatible with official Burning Man API",
          version: "0.2",
          endpoints: {
            camps: {
              url: "/api/v1/camp",
              description: "List camps or get a specific camp",
              parameters: {
                year: "Filter by year (e.g., 2024)",
                uid: "Get specific camp by UID"
              }
            },
            art: {
              url: "/api/v1/art", 
              description: "List art installations or get a specific piece",
              parameters: {
                year: "Filter by year (e.g., 2024)",
                uid: "Get specific art by UID"
              }
            },
            events: {
              url: "/api/v1/event",
              description: "List events or get a specific event",
              parameters: {
                year: "Filter by year (e.g., 2024)",
                uid: "Get specific event by UID"
              }
            },
            infrastructure: {
              url: "/api/v1/infrastructure",
              description: "OK-OFFLINE EXCLUSIVE: Burning Man infrastructure evolution (The Man, Temple, Center Camp, etc.)",
              parameters: {
                year: "Filter by year",
                category: "Filter by category (civic, location, services, etc.)",
                infrastructure_id: "Track specific infrastructure evolution"
              }
            },
            timeline: {
              url: "/api/v1/history/timeline",
              description: "OK-OFFLINE EXCLUSIVE: Historical timeline and facts",
              parameters: {
                year: "Get events for specific year",
                decade: "Get events for decade (e.g., 1990s)"
              }
            },
            evolution: {
              url: "/api/v1/history/evolution/:id",
              description: "OK-OFFLINE EXCLUSIVE: Track infrastructure evolution over 40 years",
              example: "/api/v1/history/evolution/the-man"
            },
            year_history: {
              url: "/api/v1/history/year/:year",
              description: "OK-OFFLINE EXCLUSIVE: Complete historical context for any year (1986-2025)",
              example: "/api/v1/history/year/1986"
            }
          },
          available_years: SearchableItem.distinct.pluck(:year).sort,
          total_items: {
            camps: SearchableItem.where(item_type: 'camp').count,
            art: SearchableItem.where(item_type: 'art').count,
            events: SearchableItem.where(item_type: 'event').count,
            infrastructure: SearchableItem.where(item_type: 'infrastructure').count,
            historical_facts: SearchableItem.where(item_type: 'historical_fact').count
          }
        }
      end
      # GET /api/v1/camp?year=2024
      # GET /api/v1/camp?uid=1234
      def camps
        if params[:uid]
          # Return single camp by UID
          camp = SearchableItem.where(item_type: 'camp', uid: params[:uid]).first
          
          if camp
            render json: format_camp(camp)
          else
            render json: { error: 'Camp not found' }, status: :not_found
          end
        else
          # Return camps for year (defaults to current year)
          year = params[:year] || Time.current.year
          camps = SearchableItem.where(item_type: 'camp', year: year)
                               .order(:name)
          
          render json: camps.map { |camp| format_camp(camp) }
        end
      end
      
      # GET /api/v1/art?year=2024
      # GET /api/v1/art?uid=1234
      def art
        if params[:uid]
          # Return single art by UID
          art = SearchableItem.where(item_type: 'art', uid: params[:uid]).first
          
          if art
            render json: format_art(art)
          else
            render json: { error: 'Art not found' }, status: :not_found
          end
        else
          # Return art for year
          year = params[:year] || Time.current.year
          art_items = SearchableItem.where(item_type: 'art', year: year)
                                   .order(:name)
          
          render json: art_items.map { |art| format_art(art) }
        end
      end
      
      # GET /api/v1/event?year=2024
      # GET /api/v1/event?uid=1234
      def events
        if params[:uid]
          # Return single event by UID
          event = SearchableItem.where(item_type: 'event', uid: params[:uid]).first
          
          if event
            render json: format_event(event)
          else
            render json: { error: 'Event not found' }, status: :not_found
          end
        else
          # Return events for year
          year = params[:year] || Time.current.year
          events = SearchableItem.where(item_type: 'event', year: year)
                                .order(:name)
          
          render json: events.map { |event| format_event(event) }
        end
      end
      
      # ===== OK-OFFLINE EXCLUSIVE ENDPOINTS =====
      # These endpoints provide unique historical data not available in the official API
      
      # GET /api/v1/infrastructure?year=2024&category=civic
      def infrastructure
        items = SearchableItem.where(item_type: 'infrastructure')
        
        # Filter by year if provided
        items = items.where(year: params[:year]) if params[:year]
        
        # Filter by category if provided
        if params[:category]
          items = items.where("metadata->>'category' = ?", params[:category])
        end
        
        # Filter by infrastructure_id for evolution tracking
        if params[:infrastructure_id]
          items = items.where("metadata->>'infrastructure_id' = ?", params[:infrastructure_id])
                       .order(:year)
        else
          items = items.order(:year, :name)
        end
        
        render json: items.map { |item| format_infrastructure(item) }
      end
      
      # GET /api/v1/history/timeline?year=1986
      # GET /api/v1/history/timeline?decade=1990s
      def timeline
        items = SearchableItem.where(item_type: ['timeline_event', 'historical_fact'])
        
        if params[:year]
          items = items.where(year: params[:year])
        elsif params[:decade]
          start_year = params[:decade].to_i
          items = items.where(year: start_year..(start_year + 9))
        end
        
        items = items.order(:year, :created_at)
        
        render json: items.map { |item| format_timeline_event(item) }
      end
      
      # GET /api/v1/history/evolution/the-man
      # Track how specific infrastructure evolved over time
      def evolution
        infrastructure_id = params[:id]
        
        if infrastructure_id.blank?
          render json: { error: 'Infrastructure ID required' }, status: :bad_request
          return
        end
        
        items = SearchableItem.where(item_type: 'infrastructure')
                             .where("metadata->>'infrastructure_id' = ?", infrastructure_id)
                             .order(:year)
        
        if items.empty?
          render json: { error: 'Infrastructure not found' }, status: :not_found
          return
        end
        
        # Build evolution timeline
        evolution_data = {
          infrastructure_id: infrastructure_id,
          name: items.first.name.split(' (').first,
          years_present: items.pluck(:year),
          first_year: items.first.year,
          last_year: items.last.year,
          total_years: items.count,
          evolution: items.map do |item|
            {
              year: item.year,
              description: item.description,
              height_feet: item.metadata&.dig('height_feet'),
              coordinates: item.metadata&.dig('coordinates'),
              materials: item.metadata&.dig('materials'),
              cost: item.metadata&.dig('cost'),
              builders: item.metadata&.dig('builders'),
              significance: item.metadata&.dig('significance')
            }.compact
          end
        }
        
        render json: evolution_data
      end
      
      # GET /api/v1/history/year/1986
      # Complete historical context for a specific year
      def year_history
        year = params[:year].to_i
        
        # Get BurningManYear data if available
        burning_man_year = BurningManYear.find_by(year: year)
        
        # Get all data for this year
        camps = SearchableItem.where(item_type: 'camp', year: year).count
        art = SearchableItem.where(item_type: 'art', year: year).count
        events = SearchableItem.where(item_type: 'event', year: year).count
        infrastructure = SearchableItem.where(item_type: 'infrastructure', year: year)
        historical_facts = SearchableItem.where(item_type: 'historical_fact', year: year)
        timeline_events = SearchableItem.where(item_type: 'timeline_event', year: year)
        
        year_data = {
          year: year,
          theme: burning_man_year&.theme,
          attendance: burning_man_year&.attendance,
          location: burning_man_year&.location,
          dates: burning_man_year&.dates,
          stats: {
            camps: camps,
            art: art,
            events: events,
            infrastructure: infrastructure.count,
            historical_facts: historical_facts.count
          },
          infrastructure: infrastructure.map { |item| format_infrastructure(item) },
          historical_facts: historical_facts.map { |item| format_timeline_event(item) },
          timeline_events: timeline_events.map { |item| format_timeline_event(item) }
        }.compact
        
        render json: year_data
      end
      
      private
      
      def format_infrastructure(item)
        {
          uid: item.uid,
          name: item.name,
          description: item.description,
          year: item.year,
          category: item.metadata&.dig('category'),
          infrastructure_id: item.metadata&.dig('infrastructure_id'),
          coordinates: item.metadata&.dig('coordinates'),
          metadata: item.metadata
        }.compact
      end
      
      def format_timeline_event(item)
        {
          uid: item.uid,
          name: item.name,
          description: item.description,
          year: item.year,
          item_type: item.item_type,
          significance: item.metadata&.dig('significance'),
          metadata: item.metadata
        }.compact
      end
      
      def format_camp(camp)
        {
          uid: camp.uid,
          name: camp.name,
          description: camp.description,
          year: camp.year,
          location_string: camp.location_string,
          url: camp.url,
          contact_email: camp.metadata&.dig('contact_email'),
          hometown: camp.hometown,
          camp_id: camp.camp_id
        }.compact
      end
      
      def format_art(art)
        {
          uid: art.uid,
          name: art.name,
          description: art.description,
          artist: art.artist,
          year: art.year,
          location_string: art.location_string,
          url: art.url,
          images: art.metadata&.dig('images'),
          audio_tour_url: art.metadata&.dig('audio_tour_url')
        }.compact
      end
      
      def format_event(event)
        {
          uid: event.uid,
          name: event.name,
          description: event.description,
          event_type: event.event_type,
          year: event.year,
          location_string: event.location_string,
          url: event.url,
          all_day: event.metadata&.dig('all_day'),
          hosted_by_camp: event.metadata&.dig('hosted_by_camp'),
          hosted_by_art: event.metadata&.dig('hosted_by_art'),
          occurrence_set: event.metadata&.dig('occurrence_set')
        }.compact
      end
    end
  end
end