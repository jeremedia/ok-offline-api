module Search
  # Structured output schemas for OpenAI entity extraction
  # Using OpenAI::BaseModel for reliable, type-safe extraction
  #
  # PRODUCTION NOTES:
  # - This schema is used with the official OpenAI Ruby SDK (v0.16.0+)
  # - For batch API requests, must serialize with to_json_schema method
  # - All fields are required arrays - empty arrays for no entities
  # - Tested successfully on 23 items with 100% success rate
  #
  # Entity mappings in create_basic_entities_for_item:
  # - "names" -> "location" (for discoverability)
  # - All others map directly to their entity_type

  class BasicEntityExtraction < OpenAI::BaseModel
    required :names, OpenAI::ArrayOf[String],
             doc: "Array of proper names - camp names, art installation names, event names, organization names"

    required :locations, OpenAI::ArrayOf[String],
             doc: "Array of location references - BRC addresses, plaza names, deep playa references"

    required :activities, OpenAI::ArrayOf[String],
             doc: "Array of activities or experiences offered - workshops, classes, performances"

    required :themes, OpenAI::ArrayOf[String],
             doc: "Array of themes or topics - art themes, camp concepts, cultural references"

    required :times, OpenAI::ArrayOf[String],
             doc: "Array of time references - event times, schedules"

    required :people, OpenAI::ArrayOf[String],
             doc: "Array of notable people mentioned"

    required :item_type, OpenAI::ArrayOf[String],
             doc: "Array of item types - camp, art, event, etc."

    required :contact, OpenAI::ArrayOf[String],
             doc: "Array of contact information - emails, websites, social media, phone numbers"

    required :organizational, OpenAI::ArrayOf[String],
             doc: "Array of organizational relationships - hosted by, hometown, affiliations, partnerships"

    required :services, OpenAI::ArrayOf[String],
             doc: "Array of specific services offered - guided tours, food service, amenities, support services"

    required :schedule, OpenAI::ArrayOf[String],
             doc: "Array of schedule details - specific times, duration, frequency, recurring patterns"

    required :requirements, OpenAI::ArrayOf[String],
             doc: "Array of requirements - age restrictions, prerequisites, capacity limits, materials needed"
  end
end
