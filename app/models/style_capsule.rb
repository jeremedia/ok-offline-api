class StyleCapsule < ApplicationRecord
  validates :persona_id, presence: true
  validates :capsule_json, presence: true
  validates :confidence, numericality: { in: 0.0..1.0 }
  
  scope :valid_for, ->(persona_id:, era: nil, rights_scope: 'public', graph_version:, lexicon_version:) {
    where(
      persona_id: persona_id,
      era: era || nil,
      rights_scope: rights_scope,
      graph_version: graph_version,
      lexicon_version: lexicon_version
    ).where('expires_at > ?', Time.current)
  }
  
  scope :stale, ->(refresh_window_hours = 24) {
    where('expires_at < ?', Time.current + refresh_window_hours.hours)
  }
  
  def expired?
    expires_at && expires_at < Time.current
  end
  
  def cache_key_for_lookup
    "style_capsule:#{persona_id}:#{era || 'any'}:#{rights_scope}:#{graph_version}:#{lexicon_version}"
  end
  
  def ttl_seconds
    return 0 if expired?
    (expires_at - Time.current).to_i
  end
end
