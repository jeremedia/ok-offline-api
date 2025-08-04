# frozen_string_literal: true

# Persona Style Instrumentation
# Sets up ActiveSupport::Notifications for monitoring persona style operations

if Rails.application.config.x.persona_style&.enabled

  # Persona resolution events
  ActiveSupport::Notifications.subscribe('persona.resolve') do |name, start, finish, id, payload|
    duration = finish - start
    persona_id = payload[:persona_id]
    
    Rails.logger.info "PersonaResolve: #{persona_id} (#{duration.round(3)}s)"
    
    # In production, send to StatsD or other metrics service
    # StatsD.timing('persona.resolve.duration', duration * 1000)
    # StatsD.increment('persona.resolve.success') if payload[:success]
  end

  # Corpus collection events
  ActiveSupport::Notifications.subscribe('persona.collect_corpus') do |name, start, finish, id, payload|
    duration = finish - start
    persona_id = payload[:persona_id]
    
    Rails.logger.info "CorpusCollection: #{persona_id} (#{duration.round(3)}s)"
    
    # StatsD.timing('persona.corpus.collection_time', duration * 1000)
    # StatsD.gauge('persona.corpus.items_collected', payload[:items_count]) if payload[:items_count]
  end

  # Feature extraction events
  ActiveSupport::Notifications.subscribe('persona.extract_features') do |name, start, finish, id, payload|
    duration = finish - start
    persona_id = payload[:persona_id]
    
    Rails.logger.info "FeatureExtraction: #{persona_id} (#{duration.round(3)}s)"
    
    # StatsD.timing('persona.features.extraction_time', duration * 1000)
  end

  # Rights analysis events
  ActiveSupport::Notifications.subscribe('persona.analyze_rights') do |name, start, finish, id, payload|
    duration = finish - start
    persona_id = payload[:persona_id]
    
    Rails.logger.info "RightsAnalysis: #{persona_id} (#{duration.round(3)}s)"
    
    # StatsD.timing('persona.rights.analysis_time', duration * 1000)
  end

  # Style capsule build events
  ActiveSupport::Notifications.subscribe('persona.build_capsule') do |name, start, finish, id, payload|
    duration = finish - start
    persona_id = payload[:persona_id]
    era = payload[:era]
    require_rights = payload[:require_rights]
    
    Rails.logger.info "CapsuleBuild: #{persona_id} era=#{era} rights=#{require_rights} (#{duration.round(3)}s)"
    
    # StatsD.timing('persona.capsule.build_time', duration * 1000)
    # StatsD.increment('persona.capsule.builds_completed')
  end

  Rails.logger.info "Persona Style instrumentation initialized"

else
  Rails.logger.debug "Persona Style feature disabled - skipping instrumentation"
end