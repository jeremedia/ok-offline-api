module Search
  class HistoricalDataImportService
    attr_reader :year, :stats

    def initialize(year, generate_embeddings: false)
      @year = year.to_i
      @generate_embeddings = generate_embeddings
      @stats = { camps: 0, art: 0, events: 0, errors: [], items_for_embedding: [] }
    end

    def import_all
      Rails.logger.info "Starting historical data import for #{@year}"
      
      import_camps
      import_art
      import_events
      
      # Generate embeddings in batch if enabled
      if @generate_embeddings && @stats[:items_for_embedding].any?
        Rails.logger.info "Generating embeddings for #{@stats[:items_for_embedding].count} items"
        batch_service = BatchEmbeddingService.new
        batch_service.generate_embeddings_for_items(
          SearchableItem.where(id: @stats[:items_for_embedding])
        )
      end
      
      Rails.logger.info "Import completed for #{@year}: #{@stats.except(:items_for_embedding)}"
      @stats
    end

    private

    def data_dir
      Rails.root.join('db', 'data', 'json_archive', @year.to_s)
    end

    def import_camps
      file_path = data_dir.join('camps.json')
      return unless File.exist?(file_path)

      camps = JSON.parse(File.read(file_path))
      
      camps.each do |camp_data|
        begin
          camp = SearchableItem.find_or_initialize_by(
            item_type: 'camp',
            uid: camp_data['uid'],
            year: @year
          )
          
          # Build searchable text
          searchable_parts = [
            camp_data['name'],
            camp_data['description'],
            camp_data['hometown'],
            camp_data['location_string']
          ].compact.reject(&:empty?)
          
          camp.assign_attributes(
            name: camp_data['name'],
            description: clean_description(camp_data['description']),
            url: camp_data['url'],
            hometown: camp_data['hometown'],
            location_string: camp_data['location_string'],
            searchable_text: searchable_parts.join(' '),
            metadata: {
              location: camp_data['location'],
              landmark: camp_data['landmark'],
              contact_email: camp_data['contact_email'] # Store PII in metadata
            }.compact
          )
          
          if camp.save
            @stats[:camps] += 1
            @stats[:items_for_embedding] << camp.id if camp.saved_changes? && camp.embedding.nil?
          else
            @stats[:errors] << "Camp #{camp_data['uid']}: #{camp.errors.full_messages.join(', ')}"
          end
        rescue => e
          @stats[:errors] << "Camp #{camp_data['uid']}: #{e.message}"
        end
      end
    end

    def import_art
      file_path = data_dir.join('art.json')
      return unless File.exist?(file_path)

      art_pieces = JSON.parse(File.read(file_path))
      
      art_pieces.each do |art_data|
        begin
          art = SearchableItem.find_or_initialize_by(
            item_type: 'art',
            uid: art_data['uid'],
            year: @year
          )
          
          # Build searchable text
          searchable_parts = [
            art_data['name'],
            art_data['description'],
            art_data['artist'],
            art_data['category'],
            art_data['hometown'],
            art_data['location_string']
          ].compact.reject(&:empty?)
          
          art.assign_attributes(
            name: art_data['name'],
            description: clean_description(art_data['description']),
            artist: art_data['artist'],
            hometown: art_data['hometown'],
            url: art_data['url'],
            location_string: art_data['location_string'],
            searchable_text: searchable_parts.join(' '),
            metadata: {
              location: art_data['location'],
              category: art_data['category'],
              program: art_data['program'],
              donation_link: art_data['donation_link'],
              images: art_data['images'],
              guided_tours: art_data['guided_tours'],
              self_guided_tour_map: art_data['self_guided_tour_map'],
              contact_email: art_data['contact_email'] # Store PII in metadata
            }.compact
          )
          
          if art.save
            @stats[:art] += 1
            @stats[:items_for_embedding] << art.id if art.saved_changes? && art.embedding.nil?
          else
            @stats[:errors] << "Art #{art_data['uid']}: #{art.errors.full_messages.join(', ')}"
          end
        rescue => e
          @stats[:errors] << "Art #{art_data['uid']}: #{e.message}"
        end
      end
    end

    def import_events
      file_path = data_dir.join('events.json')
      return unless File.exist?(file_path)

      events = JSON.parse(File.read(file_path))
      
      events.each do |event_data|
        begin
          event = SearchableItem.find_or_initialize_by(
            item_type: 'event',
            uid: event_data['uid'],
            year: @year
          )
          
          # Get occurrence times
          occurrence_times = if event_data['occurrence_set']&.any?
            event_data['occurrence_set'].map do |occ|
              "#{format_time(occ['start_time'])} - #{format_time(occ['end_time'])}"
            end.join(', ')
          else
            'Time TBD'
          end
          
          # Build searchable text
          searchable_parts = [
            event_data['title'],
            event_data['description'],
            event_data.dig('event_type', 'label'),
            occurrence_times
          ].compact.reject(&:empty?)
          
          # Events typically don't have location_string or hometown
          event.assign_attributes(
            name: event_data['title'],
            description: clean_description(event_data['description']),
            event_type: event_data.dig('event_type', 'label') || 'Event',
            camp_id: event_data['hosted_by_camp'],
            url: event_data['url'],
            searchable_text: searchable_parts.join(' '),
            metadata: {
              event_id: event_data['event_id'],
              event_type: event_data['event_type'],
              occurrence_set: event_data['occurrence_set'],
              print_description: event_data['print_description'],
              slug: event_data['slug'],
              hosted_by_camp: event_data['hosted_by_camp'],
              located_at_art: event_data['located_at_art'],
              other_location: event_data['other_location'],
              check_location: event_data['check_location'],
              all_day: event_data['all_day'],
              list_online: event_data['list_online'],
              list_contact_online: event_data['list_contact_online'],
              contact: event_data['contact']
            }.compact
          )
          
          if event.save
            @stats[:events] += 1
            @stats[:items_for_embedding] << event.id if event.saved_changes? && event.embedding.nil?
          else
            @stats[:errors] << "Event #{event_data['uid']}: #{event.errors.full_messages.join(', ')}"
          end
        rescue => e
          @stats[:errors] << "Event #{event_data['uid']}: #{e.message}"
        end
      end
    end

    def clean_description(text)
      return '' if text.nil?
      
      # Remove excessive whitespace and newlines
      text.strip.gsub(/\s+/, ' ')
    end

    def format_time(time_str)
      return '' if time_str.nil?
      
      DateTime.parse(time_str).strftime('%a %l:%M %p').strip
    rescue
      time_str
    end
  end
end