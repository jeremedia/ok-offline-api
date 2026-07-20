class CreateSeasonImportRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :season_import_runs do |t|
      t.integer :year, null: false
      t.string :status, null: false, default: "queued"
      t.string :stage
      t.integer :total, null: false, default: 0
      t.integer :processed, null: false, default: 0
      t.integer :removed, null: false, default: 0
      t.jsonb :stages, null: false, default: []
      t.jsonb :metadata, null: false, default: {}
      t.text :error_message
      t.datetime :started_at
      t.datetime :heartbeat_at
      t.datetime :completed_at
      t.timestamps

      t.index [ :year, :status ]
      t.index :heartbeat_at
    end
  end
end
