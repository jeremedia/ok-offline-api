# frozen_string_literal: true

require 'test_helper'

class StyleCapsuleTest < ActiveSupport::TestCase
  def setup
    @valid_attributes = {
      persona_id: 'person:larry_harvey',
      persona_label: 'Larry Harvey',
      era: '2000-2016',
      rights_scope: 'public',
      capsule_json: {
        tone: ['reflective', 'inspirational'],
        cadence: 'medium rhythmic',
        devices: ['triads', 'imperatives'],
        vocabulary: ['principles', 'community', 'gift'],
        metaphors: ['city as vessel'],
        dos: ['ground ideas in practice'],
        donts: ['heavy jargon'],
        era: '2000-2016'
      },
      confidence: 0.78,
      sources_json: [
        { id: 'idea:ten_principles', title: 'Ten Principles', year: 2004 }
      ],
      graph_version: '2025.07',
      lexicon_version: '2025.07',
      expires_at: 7.days.from_now
    }
  end
  
  test "should create valid style capsule" do
    capsule = StyleCapsule.new(@valid_attributes)
    assert capsule.valid?
    assert capsule.save
  end
  
  test "should require persona_id" do
    capsule = StyleCapsule.new(@valid_attributes.except(:persona_id))
    assert_not capsule.valid?
    assert_includes capsule.errors[:persona_id], "can't be blank"
  end
  
  test "should require capsule_json" do
    capsule = StyleCapsule.new(@valid_attributes.except(:capsule_json))
    assert_not capsule.valid?
    assert_includes capsule.errors[:capsule_json], "can't be blank"
  end
  
  test "should validate confidence range" do
    capsule = StyleCapsule.new(@valid_attributes.merge(confidence: 1.5))
    assert_not capsule.valid?
    assert_includes capsule.errors[:confidence], "must be in 0.0..1.0"
    
    capsule.confidence = -0.1
    assert_not capsule.valid?
    
    capsule.confidence = 0.5
    assert capsule.valid?
  end
  
  test "valid_for scope should find matching capsules" do
    capsule = StyleCapsule.create!(@valid_attributes)
    
    result = StyleCapsule.valid_for(
      persona_id: 'person:larry_harvey',
      era: '2000-2016',
      rights_scope: 'public',
      graph_version: '2025.07',
      lexicon_version: '2025.07'
    )
    
    assert_includes result, capsule
  end
  
  test "valid_for scope should exclude expired capsules" do
    expired_capsule = StyleCapsule.create!(@valid_attributes.merge(expires_at: 1.day.ago))
    
    result = StyleCapsule.valid_for(
      persona_id: 'person:larry_harvey',
      era: '2000-2016',
      rights_scope: 'public',
      graph_version: '2025.07',
      lexicon_version: '2025.07'
    )
    
    assert_not_includes result, expired_capsule
  end
  
  test "stale scope should find capsules approaching expiration" do
    stale_capsule = StyleCapsule.create!(@valid_attributes.merge(expires_at: 12.hours.from_now))
    fresh_capsule = StyleCapsule.create!(@valid_attributes.merge(
      persona_id: 'person:other',
      expires_at: 2.days.from_now
    ))
    
    stale_results = StyleCapsule.stale(24) # 24 hour window
    
    assert_includes stale_results, stale_capsule
    assert_not_includes stale_results, fresh_capsule
  end
  
  test "expired? should detect expired capsules" do
    expired_capsule = StyleCapsule.new(@valid_attributes.merge(expires_at: 1.hour.ago))
    fresh_capsule = StyleCapsule.new(@valid_attributes.merge(expires_at: 1.hour.from_now))
    
    assert expired_capsule.expired?
    assert_not fresh_capsule.expired?
  end
  
  test "cache_key_for_lookup should generate consistent keys" do
    capsule = StyleCapsule.new(@valid_attributes)
    
    expected_key = "style_capsule:person:larry_harvey:2000-2016:public:2025.07:2025.07"
    assert_equal expected_key, capsule.cache_key_for_lookup
  end
  
  test "cache_key_for_lookup should handle nil era" do
    capsule = StyleCapsule.new(@valid_attributes.merge(era: nil))
    
    expected_key = "style_capsule:person:larry_harvey:any:public:2025.07:2025.07"
    assert_equal expected_key, capsule.cache_key_for_lookup
  end
  
  test "ttl_seconds should calculate remaining time" do
    future_time = 2.hours.from_now
    capsule = StyleCapsule.new(@valid_attributes.merge(expires_at: future_time))
    
    ttl = capsule.ttl_seconds
    assert ttl > 0
    assert ttl <= 7200 # 2 hours in seconds
  end
  
  test "ttl_seconds should return 0 for expired capsules" do
    expired_capsule = StyleCapsule.new(@valid_attributes.merge(expires_at: 1.hour.ago))
    
    assert_equal 0, expired_capsule.ttl_seconds
  end
end