class CreateBatchJobs < ActiveRecord::Migration[8.0]
  def change
    create_table :batch_jobs do |t|
      t.string :batch_id, null: false
      t.string :job_type, null: false
      t.string :status, null: false, default: 'pending'
      t.integer :total_items, default: 0
      t.integer :completed_items, default: 0
      t.integer :failed_items, default: 0
      t.bigint :input_tokens
      t.bigint :output_tokens
      t.decimal :total_cost, precision: 10, scale: 6
      t.decimal :estimated_cost, precision: 10, scale: 6
      t.datetime :started_at
      t.datetime :completed_at
      t.text :error_message
      t.jsonb :metadata, default: {}

      t.timestamps
    end
    
    add_index :batch_jobs, :batch_id, unique: true
    add_index :batch_jobs, :status
    add_index :batch_jobs, :job_type
    add_index :batch_jobs, :created_at
  end
end
