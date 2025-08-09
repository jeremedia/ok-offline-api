namespace :infrastructure do
  desc "Import infrastructure from frontend JSON file"
  task import: :environment do
    json_path = Rails.root.join('..', 'frontend', 'src', 'data', 'infrastructure.json')
    
    unless File.exist?(json_path)
      puts "Infrastructure JSON file not found at #{json_path}"
      exit 1
    end
    
    data = JSON.parse(File.read(json_path))
    
    puts "Importing #{data['infrastructure'].length} infrastructure items..."
    
    data['infrastructure'].each_with_index do |item, index|
      puts "Processing: #{item['name']}"
      
      # Create or update main infrastructure record
      infra = Infrastructure.find_or_initialize_by(uid: item['id'])
      
      infra.update!(
        name: item['name'],
        icon: item['icon'],
        category: item['category'],
        short_description: item['shortDescription'],
        history: item['history'],
        civic_purpose: item['civicPurpose'],
        legal_context: item['legalContext'],
        operations: item['operations'],
        position: index,
        active: true
      )
      
      # Set main coordinates if available
      if item['coordinates']
        infra.update!(
          latitude: item['coordinates'][0],
          longitude: item['coordinates'][1]
        )
      end
      
      # Import multiple locations
      if item['locations']
        infra.locations.destroy_all # Clear existing locations
        
        item['locations'].each_with_index do |loc, loc_idx|
          infra.locations.create!(
            name: loc['name'],
            latitude: loc['coordinates'][0],
            longitude: loc['coordinates'][1],
            address: loc['address'],
            notes: loc['notes'],
            position: loc_idx
          )
        end
      end
      
      # Import timeline events
      if item['timeline']
        infra.timeline_events.destroy_all
        
        item['timeline'].each_with_index do |event, evt_idx|
          infra.timeline_events.create!(
            year: event['year'],
            event: event['event'],
            position: evt_idx
          )
        end
      end
      
      # Import did you know facts
      if item['didYouKnow']
        infra.facts.destroy_all
        
        item['didYouKnow'].each_with_index do |fact, fact_idx|
          infra.facts.create!(
            content: fact,
            position: fact_idx
          )
        end
      end
      
      # Import related links
      if item['relatedLinks']
        infra.links.destroy_all
        
        item['relatedLinks'].each_with_index do |link, link_idx|
          infra.links.create!(
            title: link['title'],
            url: link['url'],
            position: link_idx
          )
        end
      end
      
      puts "  ✓ Imported #{infra.name} with #{infra.locations.count} locations, #{infra.timeline_events.count} timeline events, #{infra.facts.count} facts, #{infra.links.count} links"
    end
    
    puts "\nImport complete! #{Infrastructure.count} infrastructure items in database."
  end
  
  desc "Add new infrastructure items (Artery, DMV, etc.)"
  task add_new: :environment do
    new_items = [
      {
        uid: "artery",
        name: "Artery",
        icon: "🎨",
        category: "services",
        short_description: "The art registration and placement team that helps artists find homes for their installations throughout the city.",
        history: "The Artery began in the late 1990s as Burning Man's art installations grew beyond what could be informally placed. Originally a small team helping artists find suitable playa locations, it evolved into a comprehensive art placement and registration system. The Artery team works year-round with artists, handling everything from initial concept review to on-playa placement coordination.",
        civic_purpose: "The Artery serves as the vital link between artists and Black Rock City's urban planning. They ensure art is distributed throughout the city for maximum discovery and delight, coordinate with placement to avoid conflicts, maintain safety standards, and help artists navigate the logistics of bringing large-scale art to the playa. Their work transforms BRC from a camping area into an interactive art museum.",
        legal_context: "All registered art must comply with BLM permit requirements, including Leave No Trace principles, safety inspections for climbable/interactive pieces, and flame effects permits where applicable. The Artery maintains documentation for all registered pieces and coordinates with various city departments to ensure compliance with event safety standards.",
        operations: "The Artery operates year-round with peak activity during the spring/summer as artists finalize plans. On-playa, they run from a headquarters near Center Camp, managing last-minute placements, addressing concerns, and helping lost art find its intended location. They work closely with Heavy Machinery, Survey teams, and DPW to physically place large pieces.",
        coordinates: [40.782745263312487, -119.20648820227623],
        address: "6:00 & Rod's Ring Road"
      },
      {
        uid: "dmv",
        name: "DMV (Department of Mutant Vehicles)",
        icon: "🚗",
        category: "services",
        short_description: "Licenses and regulates art cars and mutant vehicles for safe operation in Black Rock City.",
        history: "The Department of Mutant Vehicles was established in 1997 as motorized art cars proliferated and safety concerns arose. What began as informal vehicle decoration evolved into a formal licensing system ensuring that mobile art could coexist safely with 80,000 participants. The DMV has licensed thousands of vehicles over the years, from small art bikes to massive mobile sound stages.",
        civic_purpose: "The DMV ensures that mutant vehicles enhance rather than endanger the Burning Man experience. By establishing safety standards, speed limits, and operational guidelines, they allow for radical self-expression on wheels while protecting participants. Licensed vehicles become mobile gathering spaces, art platforms, and transportation that defines Black Rock City's unique character.",
        legal_context: "Mutant vehicles must meet strict safety criteria including lighting, speed governors (5mph limit), driver licensing, and insurance requirements. The DMV works within Nevada DMV regulations for the event and coordinates with law enforcement. All vehicles must pass both a daytime and nighttime inspection to receive their license.",
        operations: "The DMV operates an inspection station where vehicles are evaluated for safety, visibility, and artistic merit. Teams of inspectors check lighting, test speed limiters, verify fire extinguishers, and ensure vehicles meet the 'radically different' appearance standard. During the event, DMV rangers monitor vehicle compliance and can revoke licenses for unsafe operation.",
        coordinates: [40.779438008105928, -119.21423844576437],
        address: "5:30 & J"
      },
      {
        uid: "placement",
        name: "Placement",
        icon: "🏕️",
        category: "services",
        short_description: "The team that creates Black Rock City's layout by assigning camp locations to create diverse, vibrant neighborhoods.",
        history: "Placement evolved from the chaotic early years when camps simply claimed space upon arrival. As the event grew, the need for urban planning became critical. Starting in the mid-1990s, Placement began pre-assigning camp locations to create intentional neighborhoods, ensure adequate fire lanes, and distribute sound camps appropriately throughout the city.",
        civic_purpose: "Placement literally builds Black Rock City by thoughtfully arranging camps to create vibrant neighborhoods. They balance sound camps with quiet zones, ensure theme camps fulfill their interactivity promises, maintain emergency access lanes, and create the diverse tapestry of experiences that makes exploring BRC magical. Their work transforms empty desert into a functioning city.",
        legal_context: "Placement operates under BLM permit requirements for camp density, fire lane widths, and emergency access. They must ensure compliance with Nevada health codes for food camps, coordinate with law enforcement for sensitive placements, and maintain detailed maps for emergency services. All placements must allow for emergency vehicle access.",
        operations: "Placement works year-round reviewing camp applications, designing city layout, and managing the complex puzzle of fitting hundreds of camps into available space. On-playa, they handle disputes, last-minute changes, and ensure camps set up in assigned locations. They coordinate with Survey for accurate placement and Gate/Perimeter for arrival management.",
        coordinates: [40.780065841922166, -119.20676566604881],
        address: "5:45 & Esplanade"
      }
    ]
    
    new_items.each_with_index do |item, index|
      puts "Adding: #{item[:name]}"
      
      infra = Infrastructure.find_or_initialize_by(uid: item[:uid])
      
      # Get the highest position
      max_position = Infrastructure.maximum(:position) || 0
      
      infra.update!(
        name: item[:name],
        icon: item[:icon],
        category: item[:category],
        short_description: item[:short_description],
        history: item[:history],
        civic_purpose: item[:civic_purpose],
        legal_context: item[:legal_context],
        operations: item[:operations],
        latitude: item[:coordinates][0],
        longitude: item[:coordinates][1],
        address: item[:address],
        position: max_position + index + 1,
        active: true
      )
      
      puts "  ✓ Added #{infra.name}"
    end
    
    puts "\nNew infrastructure items added!"
  end
  
  desc "Clear all infrastructure data"
  task clear: :environment do
    puts "Clearing all infrastructure data..."
    InfrastructurePhoto.destroy_all
    InfrastructureLink.destroy_all
    InfrastructureFact.destroy_all
    InfrastructureTimeline.destroy_all
    InfrastructureLocation.destroy_all
    Infrastructure.destroy_all
    puts "All infrastructure data cleared."
  end
end