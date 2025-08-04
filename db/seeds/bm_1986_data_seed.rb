# Burning Man 1986: The Beginning
# The spontaneous birth of a movement on Baker Beach, San Francisco
# No theme, no tickets, no infrastructure - just 20 friends and an 8-foot wooden man

puts "🔥 Seeding Burning Man 1986: The Beginning..."

# Create the inaugural year
year_1986 = BurningManYear.find_or_create_by(year: 1986) do |y|
  y.theme = nil  # No theme for the first 10 years
  y.theme_statement = nil
  
  y.attendance = 20  # Just 20 friends on a beach
  y.location = "Baker Beach, San Francisco"
  y.location_details = {
    latitude: 37.793804,
    longitude: -122.483647,
    type: "beach",
    jurisdiction: "Golden Gate National Recreation Area",
    description: "A clothing-optional beach on the southwest shore of San Francisco, with views of the Golden Gate Bridge",
    distance_from_parking: "100 yards",
    accessibility: "public_beach"
  }
  
  y.dates = {
    start_date: "1986-06-21",  # Summer Solstice
    end_date: "1986-06-21",    # Single evening event
    event_time: "20:00",       # Evening gathering
    duration_hours: 4
  }
  
  y.man_height = 8  # feet - humble beginnings
  y.man_burn_date = DateTime.parse("1986-06-21 21:00:00 -07:00")
  y.temple_burn_date = nil  # No temple until 2000
  
  y.ticket_prices = {
    admission: 0,  # Free gathering of friends
    notes: "No tickets - just an invitation to friends"
  }
  
  y.notable_events = [
    "Larry Harvey and Jerry James build an 8-foot wooden effigy",
    "Approximately 20 people gather to watch the burn",
    "Mary Grauberger plays guitar and sings during the burn",
    "The gathering is spontaneous - no planning or organization",
    "Police do not intervene despite the unpermitted fire",
    "The entire event lasts about 4 hours",
    "No one knows this will become Burning Man"
  ]
  
  y.city_layout = {
    type: "gathering",
    description: "A simple circle of friends on the beach",
    infrastructure: "none",
    camping: "none - everyone went home after"
  }
  
  y.infrastructure_config = {
    organized_elements: "none",
    structures: 0,
    vehicles: "personal cars for transport",
    services: "none",
    commerce: "none",
    volunteers: 0,
    organizers: 2  # Larry and Jerry
  }
  
  y.timeline_events = [
    {
      date: "1986-06-21 17:00",
      event: "Larry Harvey and Jerry James arrive at Baker Beach with the wooden figure",
      category: "setup"
    },
    {
      date: "1986-06-21 20:00",
      event: "Friends begin gathering on the beach",
      category: "event"
    },
    {
      date: "1986-06-21 21:00",
      event: "The 8-foot wooden man is erected and set aflame",
      category: "burn"
    },
    {
      date: "1986-06-21 21:15",
      event: "Mary Grauberger plays guitar and leads songs around the fire",
      category: "culture"
    },
    {
      date: "1986-06-21 23:00",
      event: "Gathering disperses, everyone returns home",
      category: "event"
    }
  ]
  
  y.census_data = {
    estimated_attendance: 20,
    composition: "friends and girlfriends",
    organizers: ["Larry Harvey", "Jerry James"],
    musicians: ["Mary Grauberger"],
    documentation: "no photos known to exist",
    demographics: "unknown - not recorded"
  }
end

puts "  ✓ Created BurningManYear 1986 record"

# Create Infrastructure Items for 1986 (minimal)
infrastructure_1986 = [
  {
    uid: "infrastructure-1986-the-man",
    name: "The First Man (1986)",
    item_type: "infrastructure",
    year: 1986,
    description: "The original 8-foot tall wooden figure built by Larry Harvey and Jerry James in Larry's garage. Constructed from scrap lumber with no particular design plan, it was simply meant to be burned as part of a summer solstice gathering. This spontaneous act would spawn a global movement.",
    metadata: {
      infrastructure_id: "the-man",
      category: "civic",
      coordinates: [37.793804, -122.483647],
      height_feet: 8,
      materials: ["scrap_lumber", "nails"],
      construction_time: "a few hours",
      builders: ["Larry Harvey", "Jerry James"],
      cost: "approximately $0",
      burned_at: "Baker Beach",
      significance: "The first Man, origin of Burning Man"
    }
  },
  {
    uid: "infrastructure-1986-baker-beach",
    name: "Baker Beach Gathering Site",
    item_type: "infrastructure",
    year: 1986,
    description: "Baker Beach served as the birthplace of Burning Man. A clothing-optional beach on San Francisco's western shore with dramatic views of the Golden Gate Bridge. The beach's remote location and bohemian atmosphere made it perfect for the spontaneous gathering.",
    metadata: {
      infrastructure_id: "baker-beach",
      category: "location",
      coordinates: [37.793804, -122.483647],
      type: "beach",
      jurisdiction: "National Park Service",
      features: [
        "Sandy beach",
        "Fire pits allowed at the time",
        "Clothing optional area",
        "Parking nearby",
        "Golden Gate Bridge views"
      ],
      historical_note: "Burning Man was held here 1986-1989"
    }
  }
]

# Create searchable items for infrastructure
infrastructure_1986.each do |infra|
  SearchableItem.find_or_create_by(uid: infra[:uid]) do |item|
    item.attributes = infra
  end
  puts "  ✓ Created infrastructure: #{infra[:name]}"
end

# Create Historical Facts for 1986
historical_facts_1986 = [
  {
    uid: "fact-1986-origin",
    name: "The Origin of Burning Man",
    item_type: "historical_fact",
    year: 1986,
    description: "On Summer Solstice 1986, Larry Harvey and Jerry James burned an 8-foot wooden effigy on Baker Beach with about 20 friends. Harvey later said he called friends and simply said 'Let's burn a man.' There was no deeper meaning intended - it was a spontaneous act of radical self-expression.",
    metadata: {
      category: "origin",
      significance: "founding",
      date: "1986-06-21",
      participants: 20,
      quote: "I called some friends and said, let's burn a man"
    }
  },
  {
    uid: "fact-1986-no-name",
    name: "Not Yet Called Burning Man",
    item_type: "historical_fact",
    year: 1986,
    description: "The 1986 gathering had no name. It wasn't until 1988 that Larry Harvey formally began calling the event 'Burning Man.' For the first two years, it was simply referred to as 'burning the man' or 'the man burning.'",
    metadata: {
      category: "naming",
      formal_name_year: 1988,
      early_references: ["burning the man", "the man burning", "summer solstice party"]
    }
  },
  {
    uid: "fact-1986-mary-grauberger",
    name: "The First Burning Man Musician",
    item_type: "historical_fact",
    year: 1986,
    description: "Mary Grauberger brought her guitar to the first burn and played songs as the Man burned. She became the first musician to perform at what would become Burning Man, establishing the tradition of participatory art and performance.",
    metadata: {
      category: "culture",
      person: "Mary Grauberger",
      instrument: "guitar",
      significance: "First musical performance at Burning Man"
    }
  },
  {
    uid: "fact-1986-spontaneous",
    name: "A Spontaneous Beginning",
    item_type: "historical_fact",
    year: 1986,
    description: "The first burn was completely spontaneous with no permits, planning, or organization. Larry Harvey later admitted he had no idea why he wanted to burn a man - it was simply an impulse he followed. This spontaneity would become central to Burning Man's ethos.",
    metadata: {
      category: "culture",
      permits: "none",
      planning: "none",
      harvey_quote: "I don't know why I wanted to burn it. I just did."
    }
  }
]

# Create historical facts
historical_facts_1986.each do |fact|
  SearchableItem.find_or_create_by(uid: fact[:uid]) do |item|
    item.attributes = fact
  end
  puts "  ✓ Created historical fact: #{fact[:name]}"
end

# Create Timeline Events as searchable items
timeline_1986 = [
  {
    uid: "timeline-1986-creation",
    name: "Building the First Man",
    item_type: "timeline_event",
    year: 1986,
    description: "Larry Harvey and Jerry James construct an 8-foot wooden figure in Larry's garage using scrap lumber. The figure is simple and rough, with no particular artistic vision - just something to burn.",
    metadata: {
      date: "1986-06-20",
      time: "afternoon",
      location: "Larry Harvey's garage, San Francisco",
      participants: ["Larry Harvey", "Jerry James"],
      category: "construction"
    }
  },
  {
    uid: "timeline-1986-burn",
    name: "The First Burn",
    item_type: "timeline_event", 
    year: 1986,
    description: "At approximately 9 PM on Summer Solstice, the wooden man is doused with gasoline and set aflame on Baker Beach. About 20 people watch as Mary Grauberger plays guitar. The entire event is over by 11 PM.",
    metadata: {
      date: "1986-06-21",
      time: "21:00",
      duration: "2 hours",
      location: "Baker Beach, San Francisco",
      attendees: 20,
      category: "burn"
    }
  }
]

timeline_1986.each do |event|
  SearchableItem.find_or_create_by(uid: event[:uid]) do |item|
    item.attributes = event
  end
  puts "  ✓ Created timeline event: #{event[:name]}"
end

# Generate embeddings for all 1986 items
puts "  → Generating embeddings for 1986 items..."
SearchableItem.where(year: 1986, embedding: nil).find_each do |item|
  item.generate_embedding!
  puts "    ✓ Generated embedding for: #{item.name}"
end

puts "✅ Completed seeding Burning Man 1986: The Beginning"
puts "   Total items: #{SearchableItem.where(year: 1986).count}"
puts "   Infrastructure: #{SearchableItem.where(year: 1986, item_type: 'infrastructure').count}"
puts "   Historical facts: #{SearchableItem.where(year: 1986, item_type: 'historical_fact').count}"
puts "   Timeline events: #{SearchableItem.where(year: 1986, item_type: 'timeline_event').count}"
puts ""
puts "   'We were just going to burn this thing we had built and have a party.' - Larry Harvey"