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

ActiveRecord::Schema[8.0].define(version: 2025_07_27_000753) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

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
    t.index ["embedding"], name: "index_searchable_items_on_embedding", opclass: :vector_cosine_ops, using: :hnsw
    t.index ["item_type", "year"], name: "index_searchable_items_on_item_type_and_year"
    t.index ["name"], name: "index_searchable_items_on_name"
    t.index ["uid"], name: "index_searchable_items_on_uid", unique: true
  end

  add_foreign_key "search_entities", "searchable_items"
end
