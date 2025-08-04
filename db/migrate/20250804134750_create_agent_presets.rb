class CreateAgentPresets < ActiveRecord::Migration[8.0]
  def change
    create_table :agent_presets do |t|
      t.string :name, null: false
      t.string :category, null: false
      t.text :description
      t.jsonb :config_json, null: false, default: {}
      t.boolean :active, default: true
      
      t.timestamps
      
      t.index :name, unique: true
      t.index :category
      t.index :active
    end
  end
end