class CreateApiKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :api_keys, id: :uuid do |t|
      t.references :merchant, null: false, foreign_key: true, type: :uuid
      t.string :environment, null: false
      t.string :public_key, null: false
      t.string :secret_key_digest, null: false
      # Stores first 20 chars of the secret key (e.g. "sk_test_XXXXXXXXXXXX")
      # for indexed lookup before bcrypt comparison. Not unique — bcrypt verifies correctness.
      t.string :key_prefix, null: false
      t.datetime :last_used_at
      t.datetime :revoked_at

      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :api_keys, :public_key, unique: true
    add_index :api_keys, :key_prefix
    add_index :api_keys, %i[merchant_id environment]
  end
end
