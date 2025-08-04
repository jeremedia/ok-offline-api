# frozen_string_literal: true

module Mcp
  class LocationNeighborsTool
    def self.call(camp_name:, year: nil, radius: 'adjacent')
      # Find the camp(s) we're analyzing
      query = SearchableItem.where('name ILIKE ?', "%#{camp_name}%")
                           .where(item_type: 'camp')
                           .where.not(location_string: nil)
      
      query = query.where(year: year) if year
      
      target_camps = query.order(:year)
      
      return validation_error("Camp not found") if target_camps.empty?
      
      results = {
        camp_name: camp_name,
        years_analyzed: [],
        neighbor_analysis: [],
        location_patterns: analyze_location_patterns(target_camps),
        summary: {}
      }
      
      # Analyze neighbors for each year
      target_camps.each do |camp|
        year_analysis = analyze_neighbors_for_year(camp, radius)
        results[:years_analyzed] << camp.year
        results[:neighbor_analysis] << year_analysis
      end
      
      # Generate summary
      results[:summary] = generate_neighbor_summary(results[:neighbor_analysis])
      
      results
    rescue => e
      Rails.logger.error "LocationNeighborsTool error: #{e.message}"
      {
        error: "Location analysis failed: #{e.message}",
        camp_name: camp_name
      }
    end
    
    private
    
    def self.validation_error(message)
      {
        error: message,
        camp_name: "",
        years_analyzed: [],
        neighbor_analysis: []
      }
    end
    
    def self.analyze_neighbors_for_year(camp, radius)
      location = camp.location_string
      parsed_location = parse_location(location)
      
      year_data = {
        year: camp.year,
        location: location,
        parsed_location: parsed_location,
        neighbors: []
      }
      
      if parsed_location[:time] && parsed_location[:street]
        # Find neighbors based on parsed time and street
        neighbors = find_neighbors_by_coordinates(
          camp.year, 
          parsed_location[:time], 
          parsed_location[:street], 
          camp.id,
          radius
        )
        
        year_data[:neighbors] = neighbors.map do |neighbor|
          {
            name: neighbor.name,
            location: neighbor.location_string,
            distance_description: calculate_distance_description(parsed_location, parse_location(neighbor.location_string)),
            camp_type: neighbor.item_type,
            description_snippet: neighbor.description&.truncate(100)
          }
        end
      elsif parsed_location[:landmark]
        # Find neighbors near landmarks
        neighbors = find_neighbors_by_landmark(camp.year, parsed_location[:landmark], camp.id, radius)
        
        year_data[:neighbors] = neighbors.map do |neighbor|
          {
            name: neighbor.name,
            location: neighbor.location_string,
            distance_description: "Near #{parsed_location[:landmark]}",
            camp_type: neighbor.item_type,
            description_snippet: neighbor.description&.truncate(100)
          }
        end
      else
        year_data[:neighbors] = []
        year_data[:note] = "Could not parse location format: #{location}"
      end
      
      year_data
    end
    
    def self.parse_location(location_string)
      return {} unless location_string
      
      location = location_string.strip
      
      # Parse standard time & street format (e.g., "3:30 & C", "9:00 & Esplanade")
      if location.match(/(\d+):(\d+)\s*&?\s*([A-Z][a-z]*|Esplanade)/i)
        hour = $1.to_i
        minute = $2.to_i
        street = $3.upcase
        
        return {
          time: "#{hour}:#{minute.to_s.rjust(2, '0')}",
          time_decimal: hour + (minute / 60.0),
          street: street,
          type: 'standard'
        }
      end
      
      # Parse landmark locations
      if location.match(/(Center Camp|Temple|Man|Esplanade|Rod's Ring Road|Portal)/i)
        landmark = $1
        
        # Try to extract additional coordinates near landmarks
        time_match = location.match(/(\d+):(\d+)/)
        if time_match
          hour = time_match[1].to_i
          minute = time_match[2].to_i
          return {
            landmark: landmark,
            time: "#{hour}:#{minute.to_s.rjust(2, '0')}",
            time_decimal: hour + (minute / 60.0),
            type: 'landmark_with_time'
          }
        else
          return {
            landmark: landmark,
            type: 'landmark_only'
          }
        end
      end
      
      # Parse plaza locations (e.g., "3:00 G Plaza")
      if location.match(/(\d+):(\d+)\s+([A-Z])\s+Plaza/i)
        hour = $1.to_i
        minute = $2.to_i
        street = $3.upcase
        
        return {
          time: "#{hour}:#{minute.to_s.rjust(2, '0')}",
          time_decimal: hour + (minute / 60.0),
          street: street,
          type: 'plaza'
        }
      end
      
      # Return unparsed for further analysis
      {
        raw: location,
        type: 'unparsed'
      }
    end
    
    def self.find_neighbors_by_coordinates(year, time, street, exclude_id, radius)
      # Convert time to hour for easier comparison
      target_hour = time.split(':')[0].to_i
      target_minute = time.split(':')[1].to_i
      target_decimal = target_hour + (target_minute / 60.0)
      
      # Define search ranges based on radius
      case radius
      when 'immediate'
        time_range = 0.5  # 30 minutes
        street_range = 1  # Adjacent streets
      when 'adjacent'
        time_range = 1.0  # 1 hour
        street_range = 2  # 2 streets away
      when 'neighborhood'
        time_range = 2.0  # 2 hours
        street_range = 3  # 3 streets away
      else
        time_range = 1.0
        street_range = 2
      end
      
      # Find camps with similar coordinates
      potential_neighbors = SearchableItem
        .where(year: year)
        .where(item_type: 'camp')
        .where.not(id: exclude_id)
        .where.not(location_string: nil)
      
      neighbors = []
      
      potential_neighbors.find_each do |camp|
        parsed = parse_location(camp.location_string)
        next unless parsed[:time_decimal] && parsed[:street]
        
        # Check time proximity
        time_diff = (parsed[:time_decimal] - target_decimal).abs
        # Handle wraparound (e.g., 11:30 and 1:30 are 2 hours apart, not 10)
        time_diff = [time_diff, 12 - time_diff].min
        
        # Check street proximity
        street_diff = street_distance(street, parsed[:street])
        
        if time_diff <= time_range && street_diff <= street_range
          neighbors << camp
        end
      end
      
      # Sort by proximity (time difference + street difference)
      neighbors.sort_by do |camp|
        parsed = parse_location(camp.location_string)
        time_diff = (parsed[:time_decimal] - target_decimal).abs
        time_diff = [time_diff, 12 - time_diff].min
        street_diff = street_distance(street, parsed[:street])
        time_diff + (street_diff * 0.5)  # Weight street distance less
      end.first(10)
    end
    
    def self.find_neighbors_by_landmark(year, landmark, exclude_id, radius)
      # Find other camps near the same landmark
      SearchableItem
        .where(year: year)
        .where(item_type: 'camp')
        .where('location_string ILIKE ?', "%#{landmark}%")
        .where.not(id: exclude_id)
        .limit(8)
    end
    
    def self.street_distance(street1, street2)
      # Define street ordering for distance calculation
      streets = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L']
      
      # Handle special streets
      return 0 if street1 == street2
      return 2 if [street1, street2].include?('ESPLANADE')  # Esplanade is special
      
      idx1 = streets.index(street1) || 50
      idx2 = streets.index(street2) || 50
      
      (idx1 - idx2).abs
    end
    
    def self.calculate_distance_description(loc1, loc2)
      return "Unknown proximity" unless loc1[:time_decimal] && loc2[:time_decimal]
      
      time_diff = (loc1[:time_decimal] - loc2[:time_decimal]).abs
      time_diff = [time_diff, 12 - time_diff].min
      
      street_diff = street_distance(loc1[:street] || '', loc2[:street] || '')
      
      if time_diff < 0.5 && street_diff <= 1
        "Immediate neighbor"
      elsif time_diff <= 1.0 && street_diff <= 2
        "Adjacent (#{time_diff.round(1)}h, #{street_diff} streets)"
      elsif time_diff <= 2.0 && street_diff <= 3
        "Same neighborhood"
      else
        "Nearby"
      end
    end
    
    def self.analyze_location_patterns(camps)
      patterns = {
        most_common_streets: {},
        time_sector_preferences: {},
        location_stability: "unknown",
        notable_moves: []
      }
      
      prev_location = nil
      
      camps.each do |camp|
        parsed = parse_location(camp.location_string)
        
        if parsed[:street]
          patterns[:most_common_streets][parsed[:street]] ||= 0
          patterns[:most_common_streets][parsed[:street]] += 1
        end
        
        if parsed[:time_decimal]
          sector = case parsed[:time_decimal]
                  when 0..3 then "12-3 o'clock"
                  when 3..6 then "3-6 o'clock"
                  when 6..9 then "6-9 o'clock"
                  else "9-12 o'clock"
                  end
          
          patterns[:time_sector_preferences][sector] ||= 0
          patterns[:time_sector_preferences][sector] += 1
        end
        
        if prev_location && prev_location != camp.location_string
          patterns[:notable_moves] << {
            year: camp.year,
            from: prev_location,
            to: camp.location_string
          }
        end
        
        prev_location = camp.location_string
      end
      
      # Determine stability
      if patterns[:notable_moves].length <= 1
        patterns[:location_stability] = "Very stable"
      elsif patterns[:notable_moves].length <= 3
        patterns[:location_stability] = "Somewhat mobile"
      else
        patterns[:location_stability] = "Highly mobile"
      end
      
      patterns
    end
    
    def self.generate_neighbor_summary(neighbor_analyses)
      all_neighbors = neighbor_analyses.flat_map { |ya| ya[:neighbors] }.map { |n| n[:name] }
      recurring_neighbors = all_neighbors.group_by(&:itself)
                                        .select { |name, occurrences| occurrences.length > 1 }
                                        .transform_values(&:length)
      
      total_years = neighbor_analyses.length
      avg_neighbors = neighbor_analyses.sum { |ya| ya[:neighbors].length } / total_years.to_f
      
      {
        total_years_analyzed: total_years,
        average_neighbors_per_year: avg_neighbors.round(1),
        recurring_neighbors: recurring_neighbors,
        unique_neighbors_total: all_neighbors.uniq.length,
        most_frequent_neighbor: recurring_neighbors.max_by { |name, count| count }&.first
      }
    end
  end
end