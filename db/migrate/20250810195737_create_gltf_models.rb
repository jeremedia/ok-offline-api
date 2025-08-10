class CreateGltfModels < ActiveRecord::Migration[8.0]
  def change
    create_table :gltf_models do |t|
      t.string :name
      t.text :description
      t.string :category
      t.decimal :default_width
      t.decimal :default_height
      t.decimal :default_depth

      t.timestamps
    end
  end
end
