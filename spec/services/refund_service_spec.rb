require "rails_helper"

RSpec.describe RefundService do
  let(:merchant)      { create(:merchant, environment: "sandbox", enabled_payment_methods: %w[card mada apple_pay]) }
  let(:charge)        { create(:charge, :captured, merchant: merchant, amount: 1000, currency: "SAR", provider_charge_id: "pi_test_123") }
  let(:stripe_adapter) { instance_double(Adapters::StripeAdapter) }

  let(:successful_refund_result) do
    Adapters::BaseAdapter::RefundResult.new(
      provider_refund_id: "re_test_123",
      status: "succeeded",
      failure_message: nil
    )
  end

  before do
    allow(PaymentRouterService).to receive(:for).and_return(stripe_adapter)
    allow(stripe_adapter).to receive(:refund).and_return(successful_refund_result)
    allow(LedgerService).to receive(:record_refund)
  end

  describe "#call" do
    let(:default_params) do
      { merchant: merchant, charge: charge, amount: 500, reason: "requested_by_customer" }
    end

    it "creates a refund and returns a Result" do
      result = described_class.new(**default_params).call

      expect(result.refund).to be_a(Refund)
      expect(result.refund.status).to eq("succeeded")
      expect(result.refund.amount).to eq(500)
      expect(result.refund.provider_refund_id).to eq("re_test_123")
    end

    it "calls the adapter with the correct params" do
      described_class.new(**default_params).call

      expect(stripe_adapter).to have_received(:refund).with(
        provider_charge_id: "pi_test_123",
        amount: 500,
        reason: "requested_by_customer"
      )
    end

    it "records a ledger entry on success" do
      described_class.new(**default_params).call

      expect(LedgerService).to have_received(:record_refund)
    end

    context "full refund" do
      it "transitions charge to refunded" do
        described_class.new(**default_params.merge(amount: 1000)).call

        expect(charge.reload.status).to eq("refunded")
      end
    end

    context "partial refund" do
      it "keeps charge status as captured" do
        described_class.new(**default_params.merge(amount: 400)).call

        expect(charge.reload.status).to eq("captured")
      end
    end

    context "when charge belongs to another merchant" do
      let(:other_merchant) { create(:merchant) }

      it "raises not_found error" do
        expect {
          described_class.new(merchant: other_merchant, charge: charge, amount: 500).call
        }.to raise_error(PaygateError) { |e|
          expect(e.code).to eq("not_found")
          expect(e.status).to eq(:not_found)
        }
      end
    end

    context "when charge is not captured" do
      let(:charge) { create(:charge, :authorized, merchant: merchant) }

      it "raises invalid_charge_status error" do
        expect {
          described_class.new(**default_params).call
        }.to raise_error(PaygateError) { |e|
          expect(e.code).to eq("invalid_charge_status")
          expect(e.status).to eq(:unprocessable_content)
        }
      end
    end

    context "when amount exceeds charge amount" do
      it "raises amount_exceeds_charge error" do
        expect {
          described_class.new(**default_params.merge(amount: 1500)).call
        }.to raise_error(PaygateError) { |e|
          expect(e.code).to eq("amount_exceeds_charge")
          expect(e.status).to eq(:unprocessable_content)
        }
      end
    end

    context "when amount is zero or negative" do
      it "raises invalid_amount error" do
        expect {
          described_class.new(**default_params.merge(amount: 0)).call
        }.to raise_error(PaygateError) { |e|
          expect(e.code).to eq("invalid_amount")
          expect(e.status).to eq(:unprocessable_content)
        }
      end
    end

    context "when adapter returns failure" do
      let(:failed_result) do
        Adapters::BaseAdapter::RefundResult.new(
          provider_refund_id: nil,
          status: "failed",
          failure_message: "Refund declined"
        )
      end

      before { allow(stripe_adapter).to receive(:refund).and_return(failed_result) }

      it "creates a failed refund and does not call ledger" do
        result = described_class.new(**default_params).call

        expect(result.refund.status).to eq("failed")
        expect(LedgerService).not_to have_received(:record_refund)
      end

      it "does not transition the charge to refunded" do
        described_class.new(**default_params.merge(amount: 1000)).call

        expect(charge.reload.status).to eq("captured")
      end
    end

    context "when partial refunds accumulate to full amount" do
      it "transitions charge to refunded on last partial refund" do
        # First partial refund succeeds
        described_class.new(**default_params.merge(amount: 600)).call
        expect(charge.reload.status).to eq("captured")

        # Second partial refund completes the full amount
        described_class.new(**default_params.merge(amount: 400)).call
        expect(charge.reload.status).to eq("refunded")
      end
    end
  end
end
