class CreateStyleCapsules < ActiveRecord::Migration[8.0]
  def change
    create_table :style_capsules do |t|
      t.string :persona_id, null: false
      t.string :persona_label
      t.string :era
      t.string :rights_scope, default: 'public'
      t.jsonb :capsule_json, null: false
      t.decimal :confidence, precision: 3, scale: 2
      t.jsonb :sources_json
      t.string :graph_version
      t.string :lexicon_version
      t.datetime :expires_at

      t.timestamps
    end
    
    add_index :style_capsules, [:persona_id, :era, :rights_scope, :graph_version, :lexicon_version], 
              name: 'idx_style_capsules_lookup'
  end
end
