# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_08_04_134910) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "agent_presets", force: :cascade do |t|
    t.string "name", null: false
    t.string "category", null: false
    t.text "description"
    t.jsonb "config_json", default: {}, null: false
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_agent_presets_on_active"
    t.index ["category"], name: "index_agent_presets_on_category"
    t.index ["name"], name: "index_agent_presets_on_name", unique: true
  end

  create_table "agent_usages", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.string "response_id"
    t.string "status", default: "pending"
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.integer "reasoning_tokens"
    t.decimal "input_cost", precision: 10, scale: 6
    t.decimal "output_cost", precision: 10, scale: 6
    t.decimal "total_cost", precision: 10, scale: 6
    t.float "execution_time"
    t.jsonb "tools_used", default: []
    t.jsonb "mcp_calls", default: []
    t.text "error_message"
    t.string "error_type"
    t.jsonb "metadata", default: {}
    t.string "user_identifier"
    t.string "session_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_id"], name: "index_agent_usages_on_agent_id"
    t.index ["created_at"], name: "index_agent_usages_on_created_at"
    t.index ["response_id"], name: "index_agent_usages_on_response_id"
    t.index ["session_id"], name: "index_agent_usages_on_session_id"
    t.index ["status"], name: "index_agent_usages_on_status"
    t.index ["user_identifier"], name: "index_agent_usages_on_user_identifier"
  end

  create_table "agents", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "model", default: "gpt-4.1"
    t.boolean "active", default: true
    t.float "temperature", default: 1.0
    t.float "top_p", default: 1.0
    t.integer "top_logprobs"
    t.integer "max_output_tokens"
    t.integer "max_tool_calls"
    t.boolean "parallel_tool_calls", default: true
    t.text "instructions"
    t.text "instructions_template"
    t.jsonb "text_config", default: {}
    t.jsonb "tools_config", default: []
    t.jsonb "reasoning_config", default: {}
    t.jsonb "include_options", default: []
    t.jsonb "metadata_template", default: {}
    t.jsonb "prompt_templates", default: {}
    t.string "tool_choice", default: "auto"
    t.string "safety_identifier_template"
    t.string "prompt_cache_key_template"
    t.boolean "store_responses", default: true
    t.string "service_tier", default: "auto"
    t.string "truncation_strategy", default: "disabled"
    t.boolean "supports_background", default: false
    t.boolean "supports_streaming", default: true
    t.integer "version", default: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_agents_on_active"
    t.index ["model"], name: "index_agents_on_model"
    t.index ["name"], name: "index_agents_on_name", unique: true
  end

  create_table "batch_jobs", force: :cascade do |t|
    t.string "batch_id", null: false
    t.string "job_type", null: false
    t.string "status", default: "pending", null: false
    t.integer "total_items", default: 0
    t.integer "completed_items", default: 0
    t.integer "failed_items", default: 0
    t.bigint "input_tokens"
    t.bigint "output_tokens"
    t.decimal "total_cost", precision: 10, scale: 6
    t.decimal "estimated_cost", precision: 10, scale: 6
    t.datetime "started_at"
    t.datetime "completed_at"
    t.text "error_message"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["batch_id"], name: "index_batch_jobs_on_batch_id", unique: true
    t.index ["created_at"], name: "index_batch_jobs_on_created_at"
    t.index ["job_type"], name: "index_batch_jobs_on_job_type"
    t.index ["status"], name: "index_batch_jobs_on_status"
  end

  create_table "burning_man_years", force: :cascade do |t|
    t.integer "year"
    t.string "theme"
    t.text "theme_statement"
    t.integer "attendance"
    t.string "location"
    t.jsonb "dates"
    t.integer "man_height"
    t.jsonb "ticket_prices"
    t.text "notable_events", default: [], array: true
    t.jsonb "city_layout", default: {}
    t.jsonb "infrastructure_config", default: {}
    t.jsonb "timeline_events", default: []
    t.jsonb "census_data", default: {}
    t.jsonb "location_details", default: {}
    t.datetime "man_burn_date"
    t.datetime "temple_burn_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["year"], name: "index_burning_man_years_on_year", unique: true
  end

  create_table "search_entities", force: :cascade do |t|
    t.bigint "searchable_item_id"
    t.string "entity_type", null: false
    t.string "entity_value", null: false
    t.float "confidence"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["entity_type", "entity_value"], name: "index_search_entities_on_entity_type_and_entity_value"
    t.index ["entity_value"], name: "index_search_entities_on_entity_value"
    t.index ["searchable_item_id"], name: "index_search_entities_on_searchable_item_id"
  end

  create_table "search_queries", force: :cascade do |t|
    t.text "query", null: false
    t.string "search_type"
    t.json "results"
    t.float "execution_time"
    t.string "user_session"
    t.integer "result_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_search_queries_on_created_at"
    t.index ["search_type"], name: "index_search_queries_on_search_type"
  end

  create_table "searchable_items", force: :cascade do |t|
    t.string "uid", null: false
    t.string "item_type", null: false
    t.integer "year", null: false
    t.string "name", null: false
    t.text "description"
    t.text "searchable_text"
    t.vector "embedding", limit: 1536
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "artist"
    t.string "event_type"
    t.string "camp_id"
    t.string "url"
    t.string "hometown"
    t.string "location_string"
    t.index ["artist"], name: "index_searchable_items_on_artist"
    t.index ["camp_id"], name: "index_searchable_items_on_camp_id"
    t.index ["embedding"], name: "index_searchable_items_on_embedding", opclass: :vector_cosine_ops, using: :hnsw, comment: "HNSW index for cosine similarity search on embeddings"
    t.index ["event_type"], name: "index_searchable_items_on_event_type"
    t.index ["hometown"], name: "index_searchable_items_on_hometown"
    t.index ["item_type", "year"], name: "index_searchable_items_on_item_type_and_year"
    t.index ["location_string"], name: "index_searchable_items_on_location_string"
    t.index ["name"], name: "index_searchable_items_on_name"
    t.index ["uid"], name: "index_searchable_items_on_uid", unique: true
    t.index ["url"], name: "index_searchable_items_on_url"
    t.index ["year", "item_type"], name: "index_searchable_items_on_year_and_item_type"
    t.index ["year", "location_string"], name: "index_searchable_items_on_year_and_location_string"
    t.check_constraint "item_type::text = ANY (ARRAY['camp'::character varying, 'art'::character varying, 'event'::character varying, 'experience_story'::character varying, 'historical_fact'::character varying, 'infrastructure'::character varying, 'practical_guide'::character varying, 'timeline_event'::character varying, 'essay'::character varying, 'speech'::character varying, 'philosophical_text'::character varying, 'manifesto'::character varying, 'interview'::character varying, 'letter'::character varying, 'note'::character varying, 'theme_essay'::character varying, 'policy_essay'::character varying]::text[])", name: "searchable_items_item_type_check"
  end

  create_table "style_capsules", force: :cascade do |t|
    t.string "persona_id", null: false
    t.string "persona_label"
    t.string "era"
    t.string "rights_scope", default: "public"
    t.jsonb "capsule_json", null: false
    t.decimal "confidence", precision: 3, scale: 2
    t.jsonb "sources_json"
    t.string "graph_version"
    t.string "lexicon_version"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["persona_id", "era", "rights_scope", "graph_version", "lexicon_version"], name: "idx_style_capsules_lookup"
  end

  add_foreign_key "agent_usages", "agents"
  add_foreign_key "search_entities", "searchable_items"
end
