class LedgerService
  def self.record_captured_charge(charge:)
    ActiveRecord::Base.transaction do
      LedgerEntry.create!(
        merchant: charge.merchant,
        charge_id: charge.id,
        entry_type: "debit",
        amount: charge.amount,
        currency: charge.currency,
        description: "Charge captured: #{charge.id}"
      )
      LedgerEntry.create!(
        merchant: charge.merchant,
        charge_id: charge.id,
        entry_type: "credit",
        amount: charge.amount,
        currency: charge.currency,
        description: "Funds received from processor: #{charge.id}"
      )
    end
  end

  def self.record_refund(charge:, refund:)
    ActiveRecord::Base.transaction do
      LedgerEntry.create!(
        merchant: charge.merchant,
        charge_id: charge.id,
        refund_id: refund.id,
        entry_type: "credit",
        amount: refund.amount,
        currency: charge.currency,
        description: "Refund issued: #{refund.id}"
      )
      LedgerEntry.create!(
        merchant: charge.merchant,
        charge_id: charge.id,
        refund_id: refund.id,
        entry_type: "debit",
        amount: refund.amount,
        currency: charge.currency,
        description: "Refund settled: #{refund.id}"
      )
    end
  end

  def self.record_void(charge:)
    ActiveRecord::Base.transaction do
      LedgerEntry.create!(
        merchant: charge.merchant,
        charge_id: charge.id,
        entry_type: "debit",
        amount: charge.amount,
        currency: charge.currency,
        description: "Authorization voided: #{charge.id}"
      )
      LedgerEntry.create!(
        merchant: charge.merchant,
        charge_id: charge.id,
        entry_type: "credit",
        amount: charge.amount,
        currency: charge.currency,
        description: "Authorization reversed: #{charge.id}"
      )
    end
  end
end
