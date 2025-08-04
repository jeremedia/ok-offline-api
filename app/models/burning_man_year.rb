class BurningManYear < ApplicationRecord
  # Associations
  has_many :searchable_items, foreign_key: :year, primary_key: :year
  
  # Validations
  validates :year, presence: true, uniqueness: true
  validates :year, inclusion: { in: 1986..2100 }
  validates :location, presence: true
  
  # Scopes
  scope :chronological, -> { order(:year) }
  scope :with_theme, -> { where.not(theme: nil) }
  scope :desert_era, -> { where("year >= ?", 1990) }
  scope :baker_beach_era, -> { where("year < ?", 1990) }
  
  # Class methods
  def self.current
    find_by(year: Date.current.year) || last
  end
  
  def self.by_decade
    chronological.group_by { |y| (y.year / 10) * 10 }
  end
  
  # Instance methods
  def display_name
    "#{year}: #{theme || 'No Theme'}"
  end
  
  def era
    case year
    when 1986..1989 then "Baker Beach"
    when 1990..1995 then "Early Desert"
    when 1996..2005 then "Theme Era"
    when 2006..2019 then "Modern Era"
    when 2020..2021 then "Pandemic Era"
    else "Current Era"
    end
  end
  
  def has_full_data?
    year >= 2022 # We have full camp/art/event data from 2022 onward
  end
  
  def infrastructure_items
    # Helper to get infrastructure for this year
    searchable_items.where(item_type: 'infrastructure')
  end
  
  def to_api_format
    {
      year: year,
      theme: theme,
      theme_statement: theme_statement,
      attendance: attendance,
      location: location,
      location_details: location_details,
      dates: dates,
      man_height: man_height,
      man_burn_date: man_burn_date,
      temple_burn_date: temple_burn_date,
      ticket_prices: ticket_prices,
      era: era,
      notable_events: notable_events,
      timeline_events: timeline_events,
      census_data: census_data,
      city_layout: city_layout,
      has_full_data: has_full_data?
    }
  end
end