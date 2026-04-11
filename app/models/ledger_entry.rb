class LedgerEntry < ApplicationRecord
  belongs_to :merchant

  ENTRY_TYPES = %w[debit credit].freeze

  validates :entry_type, inclusion: { in: ENTRY_TYPES }
  validates :amount,     presence: true, numericality: { only_integer: true }
  validates :currency,   presence: true, length: { is: 3 }

  scope :for_charge, ->(charge_id) { where(charge_id: charge_id) }
  scope :for_refund, ->(refund_id) { where(refund_id: refund_id) }
end
