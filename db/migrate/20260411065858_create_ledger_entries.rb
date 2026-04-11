class CreateLedgerEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :ledger_entries, id: :uuid do |t|
      t.references :merchant,   type: :uuid, null: false, foreign_key: true
      # charge_id / refund_id stored as plain UUIDs — no FK constraints (partitioned table + immutability)
      t.uuid       :charge_id
      t.uuid       :refund_id
      t.string     :entry_type, null: false   # debit | credit
      t.integer    :amount,     null: false
      t.string     :currency,   null: false
      t.string     :description

      t.datetime   :created_at, null: false
    end

    add_index :ledger_entries, :charge_id
    add_index :ledger_entries, :refund_id
  end
end
