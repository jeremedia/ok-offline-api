# OKNOTOK 2025 Camp Data
# Based on CSV data from /oknotok 2025 data/

puts "🏕️  Seeding OKNOTOK 2025 camp data..."

# Create or find the OKNOTOK theme camp
camp = ThemeCamp.find_or_create_by(slug: 'oknotok', year: 2025) do |c|
  c.name = 'OKNOTOK'
  c.description = 'OKNOTOK camp for Burning Man 2025 - home of OK-OFFLINE'
  c.year = 2025
  c.is_active = true
end

puts "✅ Created/found camp: #{camp.name} (ID: #{camp.id})"

# Team member data from CSV
team_data = [
  {
    first_name: 'Mack',
    last_name: 'Reed',
    email: 'mack@mackreed.co',
    phone: '3107223392',
    arrival_date: Date.new(2025, 8, 28), # Thursday late night -> Friday
    departure_date: Date.new(2025, 9, 2), # Tuesday, September 2
    role: 'veteran',
    dietary_restrictions: 'None specified',
    skills: 'Gong fights, Jenga-style games'
  },
  {
    first_name: 'Peggy',
    last_name: 'Su',
    email: 'peggy@example.com', # Email not provided in CSV
    phone: '',
    arrival_date: Date.new(2025, 8, 29), # Friday/Saturday -> Friday
    departure_date: nil, # "not sure yet"
    role: 'veteran',
    dietary_restrictions: 'None specified',
    skills: 'Chili cooking'
  },
  {
    first_name: 'Eric',
    last_name: 'Hinote',
    email: 'ejnote@gmail.com',
    phone: '9045660315',
    arrival_date: Date.new(2025, 8, 29), # Friday morning
    departure_date: Date.new(2025, 9, 1), # Monday, September 1
    role: 'veteran',
    dietary_restrictions: 'As keto as possible but I like pizza too',
    skills: 'Birria tacos'
  },
  {
    first_name: 'Abby',
    last_name: 'Hinote',
    playa_name: 'Abby Bootty',
    email: 'abby.hinote@gmail.com',
    phone: '8502912922',
    arrival_date: Date.new(2025, 8, 29), # Friday morning
    departure_date: Date.new(2025, 9, 1), # Monday, September 1
    role: 'veteran',
    dietary_restrictions: 'None specified',
    skills: 'Birria Tacos'
  },
  {
    first_name: 'Mike',
    last_name: 'Zanti',
    email: 'mzanti123@gmail.com',
    phone: '9783945842',
    arrival_date: Date.new(2025, 8, 27), # Wednesday
    departure_date: Date.new(2025, 8, 29), # Friday, August 29
    role: 'veteran',
    dietary_restrictions: 'None specified',
    skills: 'Lobster rolls'
  },
  {
    first_name: 'Jeremy',
    last_name: 'Roush',
    email: 'j@oknotok.com',
    phone: '2135036665',
    arrival_date: Date.new(2025, 8, 27), # Wednesday
    departure_date: Date.new(2025, 9, 2), # Tuesday, September 2
    role: 'camp_lead',
    dietary_restrictions: 'Not really. No pointless carbs to waste insulin on.',
    skills: 'OK Trailer, shelving building'
  },
  {
    first_name: 'Thorarinn',
    last_name: 'Bjornsson',
    playa_name: 'Thor',
    email: 'lightningcarpentry@gmail.com',
    phone: '7062020858',
    arrival_date: Date.new(2025, 8, 29), # Friday afternoon/evening
    departure_date: Date.new(2025, 9, 1), # Monday, September 1
    role: 'veteran',
    dietary_restrictions: 'None specified',
    skills: 'Steak, potatoes and salad, Lightning Carpentry'
  },
  {
    first_name: 'Monica',
    last_name: 'Ravizza',
    playa_name: 'Mo',
    email: 'Mo@OKNOTOK.com',
    phone: '3108901596',
    arrival_date: Date.new(2025, 8, 28), # Thursday
    departure_date: Date.new(2025, 8, 31), # Sunday, August 31: Breakdown day!
    role: 'veteran',
    dietary_restrictions: 'None specified',
    skills: 'Healing Herbal Facials, Green Chile Chicken Stew'
  }
]

# Create team members
team_data.each do |member_data|
  member = TeamMember.find_or_create_by(
    email: member_data[:email],
    theme_camp: camp
  ) do |tm|
    tm.first_name = member_data[:first_name]
    tm.last_name = member_data[:last_name]
    tm.playa_name = member_data[:playa_name]
    tm.phone = member_data[:phone]
    tm.arrival_date = member_data[:arrival_date]
    tm.departure_date = member_data[:departure_date]
    tm.role = member_data[:role]
    tm.dietary_restrictions = member_data[:dietary_restrictions]
    tm.skills = member_data[:skills]
    tm.is_verified = true
  end
  
  puts "✅ Created/found team member: #{member.display_name} (#{member.arrival_date} - #{member.departure_date || 'TBD'})"
end

# Set Jeremy as camp lead
jeremy = camp.team_members.find_by(email: 'j@oknotok.com')
if jeremy
  camp.update(camp_lead: jeremy)
  puts "✅ Set #{jeremy.display_name} as camp lead"
end

puts "\n🎯 OKNOTOK 2025 Summary:"
puts "   Camp: #{camp.name} (#{camp.slug})"
puts "   Members: #{camp.team_members.count}"
puts "   Arrival dates: #{camp.team_members.pluck(:arrival_date).compact.uniq.sort.join(', ')}"
puts "   Departure dates: #{camp.team_members.pluck(:departure_date).compact.uniq.sort.join(', ')}"
puts "   Camp lead: #{camp.camp_lead_name}"
puts "\n✨ Seed complete! Test at: /api/v1/theme_camps/oknotok"