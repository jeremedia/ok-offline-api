class CreateAgentUsages < ActiveRecord::Migration[8.0]
  def change
    create_table :agent_usages do |t|
      t.references :agent, null: false, foreign_key: true
      t.string :response_id
      t.string :status, default: "pending"
      
      # Token usage
      t.integer :input_tokens
      t.integer :output_tokens
      t.integer :reasoning_tokens
      
      # Cost tracking
      t.decimal :input_cost, precision: 10, scale: 6
      t.decimal :output_cost, precision: 10, scale: 6
      t.decimal :total_cost, precision: 10, scale: 6
      
      # Execution details
      t.float :execution_time
      t.jsonb :tools_used, default: []
      t.jsonb :mcp_calls, default: []
      
      # Error tracking
      t.text :error_message
      t.string :error_type
      
      # Additional metadata
      t.jsonb :metadata, default: {}
      t.string :user_identifier
      t.string :session_id
      
      t.timestamps
      
      t.index :response_id
      t.index :status
      t.index :created_at
      t.index :user_identifier
      t.index :session_id
    end
  end
end