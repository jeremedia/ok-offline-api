class CreateThemes < ActiveRecord::Migration[7.1]
  def change
    create_table :themes do |t|
      t.string :theme_id, null: false, index: { unique: true }
      t.string :name, null: false
      t.text :description
      t.json :colors, null: false
      t.json :typography
      t.integer :position, default: 0
      t.boolean :active, default: true
      t.timestamps
    end
    
    add_index :themes, [:active, :position]
  end
end