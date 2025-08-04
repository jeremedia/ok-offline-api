# Burning Man 2003: Beyond Belief
# A year of questioning faith, reality, and the nature of belief itself
# Attendance: 30,586 - crossing the 30k threshold for the first time

puts "🔥 Seeding Burning Man 2003: Beyond Belief..."

# Create or update the year record
year_2003 = BurningManYear.find_or_create_by(year: 2003) do |y|
  y.theme = "Beyond Belief"
  y.theme_statement = "Beyond Belief will voyage into realms that lie well outside the borders of orthodoxy. This year's art theme will question, examine, and subvert many kinds of belief, from the religious and transcendent visions that are the foundation of faith to those hardheaded assumptions that are the stuff of science."
  
  y.attendance = 30586  # First year over 30,000!
  y.location = "Black Rock Desert, Nevada"
  y.location_details = {
    latitude: 40.786400,
    longitude: -119.203400,
    elevation_feet: 3907,
    distance_from_reno_miles: 120,
    distance_from_sf_miles: 350,
    playa_temperature_range: "40°F - 107°F"
  }
  
  y.dates = {
    start_date: "2003-08-25",
    end_date: "2003-09-01",
    gate_opening: "2003-08-24 00:01",  # Sunday midnight
    man_burn: "2003-08-30 21:00",      # Saturday night
    temple_burn: "2003-08-31 20:00",   # Sunday night
    build_week_start: "2003-08-11"
  }
  
  y.man_height = 80  # feet
  y.man_burn_date = DateTime.parse("2003-08-30 21:00:00 -07:00")
  y.temple_burn_date = DateTime.parse("2003-08-31 20:00:00 -07:00")
  
  y.ticket_prices = {
    advance: 175,
    tier_1: 200,
    tier_2: 225,
    gate: 250,
    kids_under_18: "free"
  }
  
  y.notable_events = [
    "First year attendance exceeded 30,000 participants",
    "Temple of Honor built by David Best and crew",
    "First year with formal Greeter Station at gate",
    "Introduction of more sophisticated placement system",
    "Major expansion of Center Camp cafe structure",
    "First appearance of the Thunderdome",
    "Opulent Temple of Venus art car debuts"
  ]
  
  y.city_layout = {
    clock_positions: ["2:00", "3:00", "4:00", "4:30", "5:00", "5:30", "6:00", "6:30", "7:00", "7:30", "8:00", "9:00", "10:00"],
    streets: {
      radial: ["2:00", "2:30", "3:00", "3:30", "4:00", "4:30", "5:00", "5:30", "6:00", "6:30", "7:00", "7:30", "8:00", "8:30", "9:00", "9:30", "10:00"],
      concentric: ["Esplanade", "Authority", "Belief", "Creed", "Dogma", "Evidence", "Faith", "Gospel", "Hope"],
      city_diameter_feet: 7920,  # 1.5 miles
      center_camp_diameter: 200,
      cafe_located_at: "6:00 & Aware"
    },
    total_area_acres: 700,
    camping_density: "increasing with population"
  }
  
  y.infrastructure_config = {
    theme_camps: 470,
    registered_art_cars: 378,
    porta_potties: 1100,
    medical_stations: 4,  # Rampart + 3 outposts
    ranger_outposts: 2,
    ice_locations: 1,  # Only at Center Camp in 2003
    dpw_crew_size: 120,
    cafe_volunteers: 300
  }
  
  y.timeline_events = [
    {
      date: "2003-02-15",
      event: "Beyond Belief theme announced",
      category: "planning"
    },
    {
      date: "2003-08-11",
      event: "DPW begins city survey and setup",
      category: "infrastructure"
    },
    {
      date: "2003-08-24",
      event: "Gates open at midnight - first arrivals",
      category: "event"
    },
    {
      date: "2003-08-26",
      event: "Temple of Honor construction completed",
      category: "infrastructure"
    },
    {
      date: "2003-08-30",
      event: "The Man burns - pyrotechnics malfunction causes early ignition",
      category: "burn"
    },
    {
      date: "2003-08-31",
      event: "Temple of Honor burns in solemn ceremony",
      category: "burn"
    },
    {
      date: "2003-09-01",
      event: "Exodus begins - smooth traffic flow reported",
      category: "event"
    }
  ]
  
  y.census_data = {
    virgin_burners_percent: 42,
    international_percent: 15,
    gender: {
      male: 58,
      female: 42
    },
    average_age: 32,
    arrival_by_day: {
      sunday: 15,
      monday: 25,
      tuesday: 20,
      wednesday: 15,
      thursday: 15,
      friday: 8,
      saturday: 2
    }
  }
end

puts "  ✓ Created BurningManYear 2003 record"

# Create Infrastructure Items for 2003
infrastructure_2003 = [
  {
    uid: "infrastructure-2003-the-man",
    name: "The Man (2003)",
    item_type: "infrastructure",
    year: 2003,
    description: "An 80-foot tall wooden figure standing atop a 30-foot pyramid base. The 2003 Man featured a more elaborate lighting system with programmable neon tubes creating patterns throughout the week. The theme 'Beyond Belief' was reflected in religious iconography around the base.",
    metadata: {
      infrastructure_id: "the-man",
      category: "civic",
      coordinates: [40.786400, -119.203400],
      height_feet: 80,
      base_height_feet: 30,
      burn_time: "2003-08-30T21:00:00-07:00",
      materials: ["douglas_fir", "steel_frame", "neon_lighting"],
      construction_crew_size: 25,
      special_features: [
        "Programmable neon light sequences",
        "Religious symbols on pyramid base",
        "Viewing platforms at multiple levels",
        "Early burn due to pyrotechnic malfunction"
      ]
    }
  },
  {
    uid: "infrastructure-2003-temple-of-honor",
    name: "Temple of Honor",
    item_type: "infrastructure", 
    year: 2003,
    description: "David Best's 2003 Temple honored firefighters, soldiers, and all those who serve and sacrifice. Built from recycled wooden dinosaur puzzle pieces, the ornate structure featured multiple spires reaching 80 feet high. Thousands left tributes to lost loved ones, especially those lost in 9/11 and the Iraq War.",
    metadata: {
      infrastructure_id: "temple",
      category: "civic",
      coordinates: [40.791815, -119.196622],
      height_feet: 80,
      footprint_sq_feet: 10000,
      artist: "David Best and the Temple Crew",
      burn_time: "2003-08-31T20:00:00-07:00",
      materials: ["recycled_wood", "plywood_cutouts", "white_paint"],
      visitors_per_day: 5000,
      special_significance: "Dedicated to those who serve and sacrifice"
    }
  },
  {
    uid: "infrastructure-2003-center-camp",
    name: "Center Camp (2003)",
    item_type: "infrastructure",
    year: 2003,
    description: "The heart of Black Rock City, featuring a massive 200-foot diameter shade structure and the only commercial operation - Center Camp Café. The 2003 design featured improved acoustic panels and an expanded performance area hosting hundreds of scheduled events.",
    metadata: {
      infrastructure_id: "center-camp",
      category: "civic",
      coordinates: [40.781089, -119.210735],
      diameter_feet: 200,
      height_feet: 40,
      coffee_sold_gallons: 15000,
      events_hosted: 400,
      volunteer_hours: 8000,
      improvements_2003: [
        "Acoustic treatment for better sound",
        "Expanded stage area",
        "Additional shade wings",
        "Improved café workflow"
      ]
    }
  },
  {
    uid: "infrastructure-2003-greeter-station",
    name: "Greeter Station",
    item_type: "infrastructure",
    year: 2003,
    description: "2003 marked the first year of the formal Greeter Station, where virgin burners were welcomed with hugs, given playa names, and invited to ring a bell announcing their arrival. This became an instant tradition and emotional entry point to the city.",
    metadata: {
      infrastructure_id: "greeter-station",
      category: "services",
      coordinates: [40.771234, -119.215678],
      established: 2003,
      volunteers_per_shift: 20,
      virgins_greeted: 12845,
      traditions_started: [
        "Virgin bell ringing",
        "Dust angel making",
        "Playa name gifting",
        "Welcome Home greeting"
      ]
    }
  }
]

# Create searchable items for infrastructure
infrastructure_2003.each do |infra|
  SearchableItem.find_or_create_by(uid: infra[:uid]) do |item|
    item.attributes = infra
  end
  puts "  ✓ Created infrastructure: #{infra[:name]}"
end

# Create Historical Facts for 2003
historical_facts_2003 = [
  {
    uid: "fact-2003-30k-milestone",
    name: "30,000 Participant Milestone",
    item_type: "historical_fact",
    year: 2003,
    description: "Burning Man crossed the 30,000 participant threshold for the first time in 2003 with 30,586 attendees. This represented a 40% increase from 2002's 28,979 and marked the beginning of rapid growth that would continue through the decade.",
    metadata: {
      category: "milestone",
      significance: "major",
      growth_rate: 40,
      previous_year_attendance: 28979
    }
  },
  {
    uid: "fact-2003-thunderdome",
    name: "First Thunderdome",
    item_type: "historical_fact",
    year: 2003,
    description: "Death Guild brought the first Thunderdome to Burning Man in 2003, inspired by Mad Max Beyond Thunderdome. Two participants suspended by bungee cords battle with foam weapons while the crowd chants 'Two men enter, one man leaves!'",
    metadata: {
      category: "culture",
      camp: "Death Guild",
      cultural_impact: "Became iconic Burning Man institution",
      inspired_by: "Mad Max Beyond Thunderdome (1985)"
    }
  },
  {
    uid: "fact-2003-early-man-burn",
    name: "The Man Burns Early",
    item_type: "historical_fact",
    year: 2003,
    description: "During the Man burn on Saturday night, a pyrotechnic malfunction caused the Man to ignite prematurely at the knees, causing him to collapse earlier than planned. The crowd's energy shifted from anticipation to surprise, but the burn was still considered successful.",
    metadata: {
      category: "incident",
      time: "21:15",
      planned_burn_time: "21:30",
      cause: "pyrotechnic_malfunction",
      crowd_reaction: "surprise_then_celebration"
    }
  }
]

# Create historical facts
historical_facts_2003.each do |fact|
  SearchableItem.find_or_create_by(uid: fact[:uid]) do |item|
    item.attributes = fact
  end
  puts "  ✓ Created historical fact: #{fact[:name]}"
end

# Create some notable theme camps from 2003 (if data available)
notable_camps_2003 = [
  {
    uid: "camp-2003-thunderdome",
    name: "Death Guild Thunderdome",
    item_type: "camp",
    year: 2003,
    description: "Home of the original Thunderdome - a geodesic dome where participants battle suspended from bungee cords. A post-apocalyptic camp bringing Mad Max to life on the playa.",
    metadata: {
      hometown: "San Francisco",
      established: 2003,
      interactivity: "Thunderdome battles",
      landmark: "Large geodesic dome",
      legacy: "Still active today"
    }
  }
]

notable_camps_2003.each do |camp|
  SearchableItem.find_or_create_by(uid: camp[:uid]) do |item|
    item.attributes = camp
  end
  puts "  ✓ Created notable camp: #{camp[:name]}"
end

# Generate embeddings for all 2003 items
puts "  → Generating embeddings for 2003 items..."
SearchableItem.where(year: 2003, embedding: nil).find_each do |item|
  item.generate_embedding!
  puts "    ✓ Generated embedding for: #{item.name}"
end

puts "✅ Completed seeding Burning Man 2003: Beyond Belief"
puts "   Total items: #{SearchableItem.where(year: 2003).count}"
puts "   Infrastructure: #{SearchableItem.where(year: 2003, item_type: 'infrastructure').count}"
puts "   Historical facts: #{SearchableItem.where(year: 2003, item_type: 'historical_fact').count}"
puts "   Camps: #{SearchableItem.where(year: 2003, item_type: 'camp').count}"