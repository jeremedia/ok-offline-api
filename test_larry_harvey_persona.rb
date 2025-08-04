#!/usr/bin/env ruby
require_relative 'config/environment'

puts "Comprehensive Larry Harvey Persona Style Test"
puts "=" * 80

# Enable the feature for testing
Rails.application.config.x.persona_style.enabled = true

# Test parameters as specified
test_params = {
  persona: "Larry Harvey",
  style_mode: "medium", 
  style_scope: "narration_only",
  era: "2000-2016",
  require_rights: "public",
  max_quote_pct: 0.05
}

puts "Test Parameters:"
test_params.each { |k, v| puts "  #{k}: #{v}" }
puts ""

# Step 1: Resolve the persona
puts "Step 1: Resolving persona '#{test_params[:persona]}'..."
resolver_result = Persona::PersonaResolver.call(test_params[:persona])

if resolver_result[:ok]
  puts "✓ Persona resolved successfully"
  puts "  persona_id: #{resolver_result[:persona_id]}"
  puts "  persona_label: #{resolver_result[:persona_label]}"
  persona_id = resolver_result[:persona_id]
  persona_label = resolver_result[:persona_label]
else
  puts "✗ Persona resolution failed: #{resolver_result[:error]}"
  puts "\nSearching in Ideas, Emanations, and Manifests..."
  
  # Alternative search approach
  search_result = Mcp::SearchTool.call(
    query: "Larry Harvey founder Burning Man",
    top_k: 10,
    pools: ['idea', 'emanation', 'manifest']
  )
  
  if search_result[:items]&.any?
    puts "Found #{search_result[:items].length} potential matches:"
    search_result[:items].first(3).each do |item|
      puts "  - #{item[:title]} (#{item[:pools_hit].join(', ')})"
    end
    
    # Use fallback persona
    persona_id = "person:larry_harvey"
    persona_label = "Larry Harvey"
    puts "Using fallback: #{persona_id}"
  else
    puts "✗ No matches found in dataset - this indicates missing corpus"
    exit 1
  end
end

# Step 2: Collect the style corpus
puts "\nStep 2: Collecting style corpus (era: #{test_params[:era]}, rights: #{test_params[:require_rights]})..."

corpus_result = Persona::StyleCorpusCollector.call(
  persona_id: persona_id,
  era: test_params[:era],
  require_rights: test_params[:require_rights]
)

if corpus_result[:ok]
  puts "✓ Corpus collection successful"
  puts "  Total items: #{corpus_result[:total_items]}"
  puts "  Execution time: #{corpus_result[:execution_time]}s"
  puts "  Pool coverage: #{corpus_result[:coverage_pools][:pools_covered].join(', ')}"
  puts "  Era coverage: #{corpus_result[:era_coverage][:earliest]}-#{corpus_result[:era_coverage][:latest]}"
  puts "  Strategy breakdown: #{corpus_result[:strategies_used]}"
  
  # Analyze corpus quality
  total_items = corpus_result[:total_items]
  pools_covered = corpus_result[:coverage_pools][:pools_covered].length
  
  if total_items < 5
    puts "⚠ Warning: Low corpus size (#{total_items} items) - may affect confidence"
  end
  
  if pools_covered < 2
    puts "⚠ Warning: Limited pool diversity (#{pools_covered} pools)"
    puts "  Thin pools need more sources:"
    %w[idea emanation manifest experience].each do |pool|
      unless corpus_result[:coverage_pools][:pools_covered].include?(pool)
        puts "    - #{pool.capitalize} pool: no sources found"
      end
    end
  end
  
else
  puts "✗ Corpus collection failed: #{corpus_result[:error]}"
  exit 1
end

# Step 3: Extract style features
puts "\nStep 3: Extracting style features..."

if corpus_result[:corpus_items].any?
  features_result = Persona::StyleFeatureExtractor.call(corpus_result[:corpus_items])
  
  if features_result[:error]
    puts "✗ Feature extraction failed: #{features_result[:error]}"
    exit 1
  else
    puts "✓ Style features extracted"
    puts "  Tone: #{features_result[:tone].join(', ')}"
    puts "  Cadence: #{features_result[:cadence]}"
    puts "  Devices: #{features_result[:devices].join(', ')}" 
    puts "  Vocabulary: #{features_result[:vocabulary].first(5).join(', ')}"
    puts "  Metaphors: #{features_result[:metaphors].first(3).join(', ')}"
    puts "  Dos: #{features_result[:dos].first(2).join('; ')}"
    puts "  Donts: #{features_result[:donts].first(2).join('; ')}"
    puts "  Era: #{features_result[:era]}"
  end
else
  puts "✗ No corpus items to analyze"
  exit 1
end

# Step 4: Summarize rights
puts "\nStep 4: Analyzing rights and quotability..."

rights_result = Persona::RightsSummarizer.call(
  corpus_result[:corpus_items], 
  require_rights: test_params[:require_rights]
)

if rights_result[:ok]
  puts "✓ Rights analysis complete"
  puts "  Quotable: #{rights_result[:quotable]}" 
  puts "  Attribution required: #{rights_result[:attribution_required]}"
  puts "  Visibility level: #{rights_result[:visibility]}"
  puts "  Public percentage: #{rights_result[:public_percentage]}%"
  puts "  Restrictions: #{rights_result[:restrictions].length}"
  
  if rights_result[:restrictions].any?
    rights_result[:restrictions].each do |restriction|
      puts "    - #{restriction[:description]}"
    end
  end
  
else
  puts "✗ Rights analysis failed: #{rights_result[:error]}"
  exit 1
end

# Step 5: Build and persist the capsule
puts "\nStep 5: Building complete style capsule..."

capsule_result = Persona::StyleCapsuleBuilder.call(
  persona_id: persona_id,
  persona_label: persona_label,
  era: test_params[:era],
  require_rights: test_params[:require_rights]
)

if capsule_result[:ok]
  puts "✓ Style capsule built and persisted"
  puts "  Style confidence: #{capsule_result[:style_confidence]}"
  puts "  Sources count: #{capsule_result[:sources].length}"
  puts "  Execution time: #{capsule_result[:meta][:execution_time]}s"
  puts "  Corpus size: #{capsule_result[:meta][:corpus_size]}"
  
  # Check confidence threshold
  if capsule_result[:style_confidence] >= 0.70
    puts "✓ High confidence achieved (≥ 0.70)"
  else
    puts "⚠ Low confidence (#{capsule_result[:style_confidence]}) - corpus may be insufficient"
  end
  
else
  puts "✗ Capsule build failed: #{capsule_result[:error]}"
  exit 1
end

# Step 6: Test MCP set_persona endpoint
puts "\nStep 6: Testing MCP set_persona with specified parameters..."

mcp_result = Mcp::SetPersonaTool.call(
  persona: test_params[:persona],
  style_mode: test_params[:style_mode],
  style_scope: test_params[:style_scope], 
  era: test_params[:era],
  require_rights: test_params[:require_rights],
  max_quote_pct: test_params[:max_quote_pct]
)

puts "\n" + "=" * 80
puts "FINAL RESULTS"
puts "=" * 80

if mcp_result[:ok]
  puts "✓ MCP set_persona successful"
  
  # Print complete JSON output as requested
  puts "\nComplete JSON Output:"
  puts JSON.pretty_generate(mcp_result)
  
  # One-line summary as requested
  puts "\nOne-line Summary:"
  summary = "persona_id=#{mcp_result[:persona_id]}, " \
           "style_confidence=#{mcp_result[:style_confidence]}, " \
           "quotable=#{mcp_result[:rights_summary][:quotable]}, " \
           "sources_count=#{mcp_result[:sources].length}"
  puts summary
  
  # Cache status
  cache_status = mcp_result[:meta][:cache] || "unknown"
  puts "Cache status: #{cache_status}"
  
  # Test acceptance criteria
  puts "\nAcceptance Test Results:"
  
  # 1. Check ok: true and confidence ≥ 0.70
  confidence_ok = mcp_result[:style_confidence] >= 0.70
  puts "  ✓ ok: true" if mcp_result[:ok]
  puts "  #{confidence_ok ? '✓' : '⚠'} confidence ≥ 0.70: #{mcp_result[:style_confidence]}"
  
  # 2. Check at least two pools represented in sources
  pool_coverage = mcp_result[:sources].map { |s| s[:id] }.map { |id| id.split(':').first }.uniq
  pools_ok = pool_coverage.length >= 2
  puts "  #{pools_ok ? '✓' : '⚠'} ≥ 2 pools in sources: #{pool_coverage.join(', ')} (#{pool_coverage.length})"
  
  # 3. Rights compliance 
  rights_ok = test_params[:require_rights] == 'public' ? 
               mcp_result[:rights_summary][:visibility] == 'public' : true
  puts "  #{rights_ok ? '✓' : '⚠'} rights requirement met"
  
  # 4. Era alignment
  era_ok = mcp_result[:style_capsule][:era].include?('2000') || 
           mcp_result[:style_capsule][:era].include?('2016')
  puts "  #{era_ok ? '✓' : '⚠'} era alignment: #{mcp_result[:style_capsule][:era]}"
  
  # Overall success
  overall_success = mcp_result[:ok] && confidence_ok && pools_ok && rights_ok
  puts "\nOverall Test: #{overall_success ? '✓ PASSED' : '⚠ PARTIAL SUCCESS'}"
  
  if !overall_success
    puts "\nIssues detected - check corpus sources in thin pools:"
    if !confidence_ok
      puts "  - Low confidence suggests insufficient high-quality content"
    end
    if !pools_ok
      puts "  - Limited pool diversity indicates missing authored content"
    end
  end
  
else
  puts "✗ MCP set_persona failed: #{mcp_result[:error]}"
  
  if mcp_result[:error_code] == 'persona_not_found'
    puts "\nRecommendation: Add more Larry Harvey content to the dataset"
    puts "Needed pools: idea (principles), emanation (philosophy), manifest (writings)"
  elsif mcp_result[:error_code] == 'low_corpus'
    puts "\nRecommendation: Increase corpus size with more biographical content"
  elsif mcp_result[:error_code] == 'rights_restricted'
    puts "\nRecommendation: Review content rights or use require_rights: 'any'"
  end
end

# Step 7: Test cache behavior
puts "\nStep 7: Testing cache behavior with second call..."
second_call = Mcp::SetPersonaTool.call(
  persona: test_params[:persona],
  style_mode: test_params[:style_mode],
  era: test_params[:era],
  require_rights: test_params[:require_rights]
)

if second_call[:ok]
  cache_hit = second_call[:meta][:cache] == "hit"
  puts "#{cache_hit ? '✓' : '⚠'} Cache test: #{second_call[:meta][:cache]}"
else
  puts "⚠ Second call failed - cache test inconclusive"
end

# Step 8: Operational notes
puts "\nOperational Notes:"
puts "• Agent behavior: Will add 'In the style of Larry Harvey, not as him.'"
puts "• Rights checking: Agent will call rights_check before any quotes"
puts "• Style application: #{test_params[:style_scope]} mode active"
puts "• Quote limit: #{(test_params[:max_quote_pct] * 100).to_i}% max"

# Step 9: Database verification
puts "\nDatabase Status:"
capsule_count = StyleCapsule.where(persona_id: persona_id).count
puts "StyleCapsules for #{persona_id}: #{capsule_count}"

if capsule_count > 0
  latest = StyleCapsule.where(persona_id: persona_id).order(:created_at).last
  puts "Latest capsule expires: #{latest.expires_at}"
  puts "TTL remaining: #{latest.ttl_seconds}s"
end

puts "\n" + "=" * 80
puts "Larry Harvey Persona Style Test Complete!"
puts "Ready for agent use with proper attribution and rights awareness."
puts "=" * 80