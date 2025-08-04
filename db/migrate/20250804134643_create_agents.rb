class CreateAgents < ActiveRecord::Migration[8.0]
  def change
    create_table :agents do |t|
      # Core fields
      t.string :name, null: false
      t.text :description
      t.string :model, default: "gpt-4.1"
      t.boolean :active, default: true
      
      # Temperature & Sampling
      t.float :temperature, default: 1.0
      t.float :top_p, default: 1.0
      t.integer :top_logprobs
      
      # Output Configuration
      t.integer :max_output_tokens
      t.integer :max_tool_calls
      t.boolean :parallel_tool_calls, default: true
      
      # Instructions
      t.text :instructions
      t.text :instructions_template
      
      # Complex configurations as JSONB
      t.jsonb :text_config, default: {}
      t.jsonb :tools_config, default: []
      t.jsonb :reasoning_config, default: {}
      t.jsonb :include_options, default: []
      t.jsonb :metadata_template, default: {}
      t.jsonb :prompt_templates, default: {}
      
      # Tool choice
      t.string :tool_choice, default: "auto"
      
      # Safety & Caching
      t.string :safety_identifier_template
      t.string :prompt_cache_key_template
      t.boolean :store_responses, default: true
      
      # Service & Performance
      t.string :service_tier, default: "auto"
      t.string :truncation_strategy, default: "disabled"
      
      # Features
      t.boolean :supports_background, default: false
      t.boolean :supports_streaming, default: true
      
      # Versioning
      t.integer :version, default: 1
      
      t.timestamps
      
      t.index :name, unique: true
      t.index :active
      t.index :model
    end
  end
end