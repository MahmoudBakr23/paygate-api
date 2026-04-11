class CreateWebhookEndpoints < ActiveRecord::Migration[8.1]
  def change
    create_table :webhook_endpoints, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :merchant, null: false, type: :uuid, foreign_key: true
      t.string :url, null: false
      t.string :events, array: true, default: %w[charge.captured charge.failed refund.created]
      t.boolean :active, null: false, default: true
      t.string :webhook_secret, null: false

      t.timestamp :created_at, null: false
    end

  end

  def down
    drop_table :webhook_endpoints
  end
end
