module Search
  class BasicEntityExtraction < OpenAI::BaseModel
    required :names, OpenAI::ArrayOf[String], doc: "Proper names"
    required :locations, OpenAI::ArrayOf[String], doc: "BRC addresses and location references"
    required :activities, OpenAI::ArrayOf[String], doc: "Activities and experiences"
    required :themes, OpenAI::ArrayOf[String], doc: "Themes and topics"
    required :times, OpenAI::ArrayOf[String], doc: "Time references"
    required :people, OpenAI::ArrayOf[String], doc: "Notable people"
    required :item_type, OpenAI::ArrayOf[String], doc: "Item types"
    required :contact, OpenAI::ArrayOf[String], doc: "Contact information"
    required :organizational, OpenAI::ArrayOf[String], doc: "Organizational relationships"
    required :services, OpenAI::ArrayOf[String], doc: "Services offered"
    required :schedule, OpenAI::ArrayOf[String], doc: "Schedule details"
    required :requirements, OpenAI::ArrayOf[String], doc: "Requirements and restrictions"
  end
end
