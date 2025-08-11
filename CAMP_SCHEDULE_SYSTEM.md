# Camp Schedule System - Implementation Reference

**Created**: August 11, 2025  
**System**: CampScheduleItem management for OKNOTOK 2025  
**Status**: ✅ Complete & Tested

## Overview

Complete camp scheduling system allowing theme camps to manage events, meals, meetings, arrivals, departures, and service tasks with team member assignments and conflict detection.

## Database Schema

### CampScheduleItem
```ruby
# Fields:
- id: bigint (primary key)
- title: string (required, max 255 chars)
- description: text
- start_datetime: datetime (required)  
- end_datetime: datetime (optional)
- location: string
- required_supplies: text
- notes: text
- category: integer (enum, required)
- status: integer (enum, required, default: 0)
- theme_camp_id: bigint (foreign key, required)
- responsible_person_id: bigint (foreign key to team_members, optional)
- api_event_uid: string (unique, for BM API integration)
- created_at/updated_at: datetime

# Indexes:
- start_datetime
- category  
- status
- api_event_uid (unique)
- [theme_camp_id, start_datetime] (compound)
```

### CampScheduleAssignment (Join Table)
```ruby
# Fields:
- id: bigint (primary key)
- camp_schedule_item_id: bigint (foreign key, required)
- team_member_id: bigint (foreign key, required)
- notes: text (assignment-specific notes)
- created_at/updated_at: datetime

# Indexes:
- [camp_schedule_item_id, team_member_id] (unique compound)
- team_member_id
```

## Enums

### Category
```ruby
public_event: 0  # Events visible to all participants
meal: 1          # Camp kitchen/dining coordination
arrival: 2       # Logistics coordination
departure: 3     # Logistics coordination  
service: 4       # Camp maintenance/duty schedules
meeting: 5       # Internal camp meetings
```

### Status  
```ruby
happening: 0     # Default - scheduled and happening
canceled: 1      # Event was canceled
happened: 2      # Event completed successfully
skipped: 3       # Event was skipped/postponed  
draft: 4         # Draft/planning status
```

## Model Relationships

### CampScheduleItem
```ruby
belongs_to :theme_camp
belongs_to :responsible_person, class_name: 'TeamMember', optional: true
has_many :camp_schedule_assignments, dependent: :destroy
has_many :team_members, through: :camp_schedule_assignments
```

### ThemeCamp (Added)
```ruby
has_many :camp_schedule_items, dependent: :destroy

# Helper methods:
def upcoming_schedule_items
def schedule_items_for_date(date)  
def public_events
```

### TeamMember (Added)
```ruby
has_many :camp_schedule_assignments, dependent: :destroy
has_many :assigned_schedule_items, through: :camp_schedule_assignments, source: :camp_schedule_item
has_many :responsible_schedule_items, class_name: 'CampScheduleItem', foreign_key: :responsible_person_id

# Helper methods:
def upcoming_assignments
def upcoming_responsibilities
def schedule_conflicts_for(start_datetime, end_datetime)
def available_for?(start_datetime, end_datetime)
```

## API Endpoints

### Base Path: `/api/v1/theme_camps/:camp_slug/schedule_items`

#### Core CRUD
- `GET /` - List schedule items (with filtering)
- `POST /` - Create schedule item
- `GET /:id` - Show schedule item with assignments
- `PUT /:id` - Update schedule item  
- `DELETE /:id` - Delete schedule item

#### Team Member Management
- `POST /:id/assign_members` - Assign team members with notes
- `DELETE /:id/unassign_member/:member_id` - Remove assignment

#### Utilities
- `GET /conflicts` - Check scheduling conflicts

### Query Parameters (for GET /)
- `category` - Filter by category
- `date` - Filter by specific date
- `start_date` & `end_date` - Filter by date range
- `include_inactive` - Include canceled/skipped items
- `q` - Search title/description/location/notes

## Frontend Service Methods

### Core Methods (campService.js)
```javascript
// CRUD Operations
getScheduleItems(campSlug, options = {})
getScheduleItem(campSlug, itemId, useCache = true)
createScheduleItem(campSlug, itemData, teamMemberIds = [])
updateScheduleItem(campSlug, itemId, itemData, teamMemberIds = null)
deleteScheduleItem(campSlug, itemId)

// Team Member Assignment
assignMembersToScheduleItem(campSlug, itemId, memberAssignments)
unassignMemberFromScheduleItem(campSlug, itemId, memberId)

// Utilities
checkScheduleConflicts(campSlug, startDatetime, endDatetime, teamMemberIds)
getScheduleItemsByCategory(campSlug, category, useCache = true)
getScheduleItemsForDateRange(campSlug, startDate, endDate, useCache = true)
getScheduleItemsForDate(campSlug, date, useCache = true)
batchUpdateScheduleItems(campSlug, updates)
```

### Caching Strategy
- Smart cache invalidation with relationships
- Cache keys include query parameters for filtering
- Offline-first architecture maintained
- Cache relationships: `schedule_items` invalidates `team_members`

## Usage Examples

### Create Schedule Item
```javascript
const scheduleData = {
  title: "Morning Coffee Setup",
  description: "Set up coffee station for camp",
  start_datetime: "2025-08-25T07:00:00-07:00",
  end_datetime: "2025-08-25T08:00:00-07:00", 
  location: "Kitchen Area",
  category: "service",
  status: "happening",
  responsible_person_id: 123,
  required_supplies: "Coffee, filters, cups"
}

const item = await createScheduleItem('oknotok', scheduleData, [123, 456])
```

### Check Conflicts
```javascript
const conflicts = await checkScheduleConflicts(
  'oknotok', 
  '2025-08-25T14:00:00-07:00',
  '2025-08-25T16:00:00-07:00',
  [123, 456]
)
```

### Assign Team Members
```javascript
const assignments = [
  { member_id: 123, notes: "Lead organizer" },
  { member_id: 456, notes: "Cleanup crew" }
]
await assignMembersToScheduleItem('oknotok', itemId, assignments)
```

## Key Features Implemented

### ✅ Advanced Scheduling
- DateTime-based scheduling (precise timing)
- Conflict detection between overlapping assignments
- Team member availability checking
- Flexible assignment system with role-specific notes

### ✅ Smart Categories
- Public events (visible to all participants)
- Meal coordination (camp kitchen management)
- Arrival/departure logistics
- Service schedules (maintenance, duties)
- Internal meetings

### ✅ Robust Relationships  
- Each schedule item belongs to a theme camp
- Many-to-many with team members (assignments)
- Optional responsible person designation
- Integration with existing personal spaces & camp maps

### ✅ Production-Ready Features
- Comprehensive validation and error handling
- Smart caching with relationship invalidation
- Offline-first architecture (cached data available offline)
- Search and filtering capabilities
- Batch operations for efficiency
- Performance indexes for fast queries

## Model Helper Methods

### CampScheduleItem
- `duration_minutes` / `duration_hours` - Calculate event duration
- `is_current?` / `is_upcoming?` / `is_past?` - Time-based status
- `category_display` / `status_display` - Human-readable enum values
- `assigned_member_names` - List of assigned team member names
- `responsible_person_name` - Name of responsible person

### Scopes
- `upcoming` - Future events
- `past` - Past events  
- `current` - Happening now
- `by_category(cat)` - Filter by category
- `active` - Exclude canceled events
- `chronological` - Order by start time
- `for_date_range(start, end)` - Date range filter

## Integration Points

### Burning Man API Integration
- `api_event_uid` field links to official BM events
- Recurring events can be imported from BM API
- Public events visible to all participants

### Existing Camp Management
- Integrates with team members system
- Links to personal spaces (responsible person)
- Uses camp map locations for event placement
- Follows existing permission system

## Testing Results

✅ **Database migrations** completed successfully  
✅ **Model associations** working correctly  
✅ **Enum handling** (avoided Rails method conflicts)  
✅ **CRUD operations** functional  
✅ **Team member assignments** with notes  
✅ **Helper methods** calculating durations and status  
✅ **Conflict detection** between overlapping events  
✅ **Cache invalidation** working properly

## Next Steps

1. **Create ScheduleEditor Vue component**
2. **Build schedule calendar/timeline view**  
3. **Implement conflict detection UI**
4. **Add to CampEditorView navigation**
5. **Test with real camp data**

---

**Implementation completed by Claude Code on August 11, 2025**  
**System ready for frontend UI development**