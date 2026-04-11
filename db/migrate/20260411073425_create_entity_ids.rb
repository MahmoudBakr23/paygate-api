class CreateEntityIds < ActiveRecord::Migration[8.1]
  def change
    create_table :entity_ids, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :merchant, null: false, type: :uuid, foreign_key: true
      t.string :brand, null: false
      t.string :environment, null: false
      t.string :entity_id, null: false

      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :entity_ids, %i[merchant_id brand environment], unique: true
  end
end
