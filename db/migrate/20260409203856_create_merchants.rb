class CreateMerchants < ActiveRecord::Migration[8.1]
  def change
    create_table :merchants, id: :uuid do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :environment, null: false, default: "sandbox"
      t.string :enabled_payment_methods, array: true, default: %w[card mada apple_pay]
      t.string :webhook_url
      t.string :webhook_secret

      t.timestamps
    end

    add_index :merchants, :email, unique: true
  end
end
