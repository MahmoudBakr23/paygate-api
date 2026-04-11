require "rails_helper"

RSpec.describe LedgerService do
  let(:merchant) { create(:merchant, environment: "sandbox") }
  let(:charge)   { create(:charge, :captured, merchant: merchant, amount: 1000, currency: "SAR") }

  describe ".record_captured_charge" do
    it "creates two ledger entries (debit + credit)" do
      expect {
        described_class.record_captured_charge(charge: charge)
      }.to change(LedgerEntry, :count).by(2)
    end

    it "creates a debit entry for the charge amount" do
      described_class.record_captured_charge(charge: charge)

      debit = LedgerEntry.find_by!(entry_type: "debit", charge_id: charge.id)
      expect(debit.amount).to eq(charge.amount)
      expect(debit.currency).to eq(charge.currency)
      expect(debit.merchant_id).to eq(merchant.id)
    end

    it "creates a credit entry for the charge amount" do
      described_class.record_captured_charge(charge: charge)

      credit = LedgerEntry.find_by!(entry_type: "credit", charge_id: charge.id)
      expect(credit.amount).to eq(charge.amount)
    end

    it "both entries are scoped to the charge" do
      described_class.record_captured_charge(charge: charge)

      entries = LedgerEntry.for_charge(charge.id)
      expect(entries.count).to eq(2)
    end
  end

  describe ".record_refund" do
    let(:refund) do
      create(:refund, merchant: merchant, charge_id: charge.id, amount: 400, status: "succeeded")
    end

    it "creates two ledger entries (credit + debit)" do
      expect {
        described_class.record_refund(charge: charge, refund: refund)
      }.to change(LedgerEntry, :count).by(2)
    end

    it "creates entries scoped to both charge_id and refund_id" do
      described_class.record_refund(charge: charge, refund: refund)

      entries = LedgerEntry.for_refund(refund.id)
      expect(entries.count).to eq(2)
      expect(entries.pluck(:charge_id).uniq).to eq([charge.id])
      expect(entries.pluck(:currency).uniq).to eq([charge.currency])
    end

    it "uses the refund amount, not the charge amount" do
      described_class.record_refund(charge: charge, refund: refund)

      expect(LedgerEntry.for_refund(refund.id).pluck(:amount).uniq).to eq([refund.amount])
    end
  end

  describe ".record_void" do
    let(:charge) { create(:charge, :authorized, merchant: merchant, amount: 1000, currency: "SAR") }

    it "creates two ledger entries" do
      expect {
        described_class.record_void(charge: charge)
      }.to change(LedgerEntry, :count).by(2)
    end

    it "creates entries for the authorized amount" do
      described_class.record_void(charge: charge)

      entries = LedgerEntry.for_charge(charge.id)
      expect(entries.pluck(:amount).uniq).to eq([charge.amount])
    end

    it "includes both debit and credit entry types" do
      described_class.record_void(charge: charge)

      types = LedgerEntry.for_charge(charge.id).pluck(:entry_type).sort
      expect(types).to eq(%w[credit debit])
    end
  end
end
