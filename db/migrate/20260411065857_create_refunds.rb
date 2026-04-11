class CreateRefunds < ActiveRecord::Migration[8.1]
  def change
    create_table :refunds, id: :uuid do |t|
      # charge_id is not a FK reference — charges is a partitioned table (app-layer integrity)
      t.uuid       :charge_id,          null: false
      t.references :merchant,           type: :uuid, null: false, foreign_key: true
      t.integer    :amount,             null: false
      t.string     :reason
      t.string     :status,             null: false, default: "pending"
      t.string     :provider_refund_id

      t.timestamps
    end

    add_index :refunds, :charge_id
    add_index :refunds, :status
  end
end
