require "rails_helper"

RSpec.describe VoidService do
  let(:merchant)       { create(:merchant, environment: "sandbox", enabled_payment_methods: %w[card mada apple_pay]) }
  let(:charge)         { create(:charge, :authorized, merchant: merchant, provider_charge_id: "pi_test_456") }
  let(:stripe_adapter) { instance_double(Adapters::StripeAdapter) }

  let(:successful_void_result) do
    Adapters::BaseAdapter::VoidResult.new(status: "voided", failure_message: nil)
  end

  before do
    allow(PaymentRouterService).to receive(:for).and_return(stripe_adapter)
    allow(stripe_adapter).to receive(:void).and_return(successful_void_result)
    allow(LedgerService).to receive(:record_void)
  end

  describe "#call" do
    it "voids the charge and returns a Result" do
      result = described_class.new(merchant: merchant, charge: charge).call

      expect(result.charge.status).to eq("voided")
    end

    it "calls the adapter void with the provider charge id" do
      described_class.new(merchant: merchant, charge: charge).call

      expect(stripe_adapter).to have_received(:void).with(provider_charge_id: "pi_test_456")
    end

    it "records a ledger void entry" do
      described_class.new(merchant: merchant, charge: charge).call

      expect(LedgerService).to have_received(:record_void).with(charge: charge)
    end

    context "when charge belongs to another merchant" do
      let(:other_merchant) { create(:merchant) }

      it "raises not_found error" do
        expect {
          described_class.new(merchant: other_merchant, charge: charge).call
        }.to raise_error(PaygateError) { |e|
          expect(e.code).to eq("not_found")
          expect(e.status).to eq(:not_found)
        }
      end
    end

    context "when charge is not authorized" do
      let(:charge) { create(:charge, :captured, merchant: merchant) }

      it "raises invalid_charge_status error" do
        expect {
          described_class.new(merchant: merchant, charge: charge).call
        }.to raise_error(PaygateError) { |e|
          expect(e.code).to eq("invalid_charge_status")
          expect(e.status).to eq(:unprocessable_content)
        }
      end
    end

    context "when adapter returns failure" do
      let(:failed_result) do
        Adapters::BaseAdapter::VoidResult.new(status: "failed", failure_message: "Cannot void at this stage")
      end

      before { allow(stripe_adapter).to receive(:void).and_return(failed_result) }

      it "raises provider_void_failed error" do
        expect {
          described_class.new(merchant: merchant, charge: charge).call
        }.to raise_error(PaygateError) { |e|
          expect(e.code).to eq("provider_void_failed")
          expect(e.status).to eq(:bad_gateway)
          expect(e.message).to eq("Cannot void at this stage")
        }
      end

      it "does not transition the charge" do
        described_class.new(merchant: merchant, charge: charge).call rescue PaygateError

        expect(charge.reload.status).to eq("authorized")
      end

      it "does not record a ledger entry" do
        described_class.new(merchant: merchant, charge: charge).call rescue PaygateError

        expect(LedgerService).not_to have_received(:record_void)
      end
    end
  end
end
