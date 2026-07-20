require_relative "../test_helper"

class EntityExtractionServiceTest < ActiveSupport::TestCase
  FakeMessage = Data.define(:parsed)
  FakeChoice = Data.define(:message)
  FakeResponse = Data.define(:choices)

  class FakeCompletions
    attr_reader :params
    def initialize(parsed) = @parsed = parsed
    def create(**params)
      @params = params
      FakeResponse.new([ FakeChoice.new(FakeMessage.new(@parsed)) ])
    end
  end

  class FakeClient
    attr_reader :completions
    def initialize(parsed) = @completions = FakeCompletions.new(parsed)
    def chat = Struct.new(:completions).new(@completions)
  end

  test "uses BasicEntityExtraction and consumes parsed structured output" do
    parsed = Search::BasicEntityExtraction.new(
      names: [ "Example" ], locations: [ "3:30 & A" ], activities: [], themes: [], times: [],
      people: [], item_type: [ "camp" ], contact: [], organizational: [], services: [],
      schedule: [], requirements: []
    )
    client = FakeClient.new(parsed)
    entities = Search::EntityExtractionService.new(client: client).extract_entities("Example at 3:30 & A", "camp")

    assert_equal Search::BasicEntityExtraction, client.completions.params[:response_format]
    assert_includes entities, { entity_type: "location", entity_value: "3:30 & A", confidence: 0.9 }
  end
end
