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

ActiveRecord::Schema[8.1].define(version: 2026_04_09_203911) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "api_keys", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "environment", null: false
    t.string "key_prefix", null: false
    t.datetime "last_used_at"
    t.uuid "merchant_id", null: false
    t.string "public_key", null: false
    t.datetime "revoked_at"
    t.string "secret_key_digest", null: false
    t.index ["key_prefix"], name: "index_api_keys_on_key_prefix"
    t.index ["merchant_id", "environment"], name: "index_api_keys_on_merchant_id_and_environment"
    t.index ["merchant_id"], name: "index_api_keys_on_merchant_id"
    t.index ["public_key"], name: "index_api_keys_on_public_key", unique: true
  end

  create_table "merchants", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "enabled_payment_methods", default: ["card", "mada", "apple_pay"], array: true
    t.string "environment", default: "sandbox", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.string "webhook_secret"
    t.string "webhook_url"
    t.index ["email"], name: "index_merchants_on_email", unique: true
  end

  add_foreign_key "api_keys", "merchants"
end
