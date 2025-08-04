# Complete Burning Man History Database (1986-2025)

## Overview
Transform the OK-OFFLINE API into a comprehensive historical archive of Burning Man from its inception in 1986 to present, providing API-compatible endpoints and full vector search/entity extraction across all years.

## Motivation
- Create the most complete searchable Burning Man historical database
- Show the evolution from 20 people on Baker Beach to 80,000+ in Black Rock City
- Provide Burning Man API-compatible endpoints for all historical data
- Enable vector search and entity extraction across the entire history

## Key Features
1. **Complete Coverage**: Every single year from 1986-2025
2. **API Compatibility**: Drop-in replacement for official Burning Man API
3. **Progressive Data**: Data richness increases as years progress (matching historical reality)
4. **Infrastructure Evolution**: Track how city services and layout evolved
5. **Rich Search**: Vector search and entity extraction across 40 years of history

## Database Schema Changes

### New Models
1. **BurningManYear**
   - year, theme, attendance, location, dates, ticket_prices
   - man_height, city_layout, infrastructure_config
   - notable_events, timeline_events

2. **Infrastructure** (from infrastructure.json)
   - Persistent infrastructure items that evolve over years
   - The Man, Temple, Center Camp, Airport, etc.

### SearchableItem Extensions
- New types: `infrastructure`, `historical_fact`, `timeline_event`
- Year-aware searching and filtering

## Implementation Phases

### Phase 1: Database Setup ✅ First Priority
- [ ] Create BurningManYear model and migration
- [ ] Add new item_type validations to SearchableItem
- [ ] Create Infrastructure model
- [ ] Seed BurningManYear data for all years (1986-2025)

### Phase 2: Historical Data Structure
- [ ] Create year directories: `/frontend/public/data/{year}/`
- [ ] Generate metadata.json for each year
- [ ] Import infrastructure.json data as searchable items
- [ ] Create historical_facts.json for major events

### Phase 3: Import Services
- [ ] Create HistoricalDataImportService
- [ ] Build year-specific data generators
- [ ] Handle progressive city layout (Baker Beach → BRC evolution)
- [ ] Generate appropriate infrastructure per year

### Phase 4: API Implementation
- [ ] Create Burning Man-compatible endpoints (`/api/v1/camp`, `/art`, `/event`)
- [ ] Add year filtering to all endpoints
- [ ] Create new history endpoints (`/years`, `/timeline`, `/infrastructure`)
- [ ] Format responses to match official API structure

### Phase 5: Search Enhancement
- [ ] Update entity extraction for historical content
- [ ] Add year-range filtering to vector search
- [ ] Create timeline-aware search
- [ ] Index all historical data with embeddings

## Historical Data by Era

### 1986-1989: Baker Beach Era
- Location: Baker Beach, San Francisco
- Data: Attendance, Man height, key facts
- Infrastructure: Minimal (location marker only)

### 1990-1995: Early Black Rock Desert
- First desert burns, growing from 80 to 4,000 people
- Basic infrastructure emergence
- Introduction of Rangers, DPW precursors

### 1996-2005: Theme Era & City Formation
- Official themes begin
- Radial city design emerges
- Center Camp, first Temples
- Theme camp placement begins

### 2006-2019: Modern Burning Man
- Full city infrastructure
- 50,000-80,000 attendance
- Complete camps/art/events data
- All modern services

### 2020-2021: Pandemic Years
- Virtual burn, cancelled events
- Historical significance

### 2022-2025: Current Era
- Full API data available
- Complete infrastructure
- Vector search enabled

## First Next Steps

1. **Create database migrations**
   ```bash
   rails generate model BurningManYear year:integer:uniq theme:string attendance:integer
   rails generate migration AddInfrastructureToSearchableItems
   ```

2. **Seed historical data**
   - Create comprehensive year data (themes, attendance, dates)
   - Import infrastructure.json as searchable items

3. **Build import rake task**
   ```bash
   rails burning_man:import_history
   rails burning_man:generate_year[1986]
   ```

4. **Create first API endpoint**
   - Start with `/api/v1/years` to list all available years

## Success Metrics
- Complete data for all 40 years of Burning Man
- API compatibility with official endpoints
- Vector search working across all years
- Infrastructure items searchable and evolving by year
- Historical timeline browseable

## Resources
- infrastructure.json (already created)
- Burning Man official timeline
- Wikipedia historical data
- ePlaya archives
- Census data from Burning Man org

This will create an unprecedented historical resource for the Burning Man community! 🔥