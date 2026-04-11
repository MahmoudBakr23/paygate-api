class CreateWebhookDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :webhook_deliveries, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :webhook_endpoint, null: false, type: :uuid, foreign_key: true
      t.string :charge_id, null: true   # plain UUID — no FK, charges table is partitioned
      t.string :event_type, null: false
      t.jsonb :payload, null: false, default: {}
      t.string :status, null: false, default: "pending"  # pending | delivered | failed | retrying
      t.integer :http_status
      t.integer :attempts, null: false, default: 0
      t.timestamp :next_retry_at
      t.timestamp :delivered_at

      t.timestamp :created_at, null: false
    end

    add_index :webhook_deliveries, :status
    add_index :webhook_deliveries, :charge_id
  end

  def down
    drop_table :webhook_deliveries
  end
end
