require "rails_helper"

RSpec.describe ChargeService do
  let(:merchant)        { create(:merchant, environment: "sandbox", enabled_payment_methods: %w[card mada apple_pay]) }
  let(:idempotency_key) { SecureRandom.uuid }

  let(:default_params) do
    {
      merchant: merchant,
      idempotency_key: idempotency_key,
      amount: 1000,
      currency: "SAR",
      payment_method: "card",
      token: "tok_visa",
      metadata: {}
    }
  end

  let(:successful_charge_result) do
    Adapters::BaseAdapter::ChargeResult.new(
      provider_charge_id: "pi_test_123",
      status: "captured",
      failure_code: nil,
      failure_message: nil
    )
  end

  let(:stripe_adapter) { instance_double(Adapters::StripeAdapter) }

  before do
    allow(PaymentRouterService).to receive(:for).and_return(stripe_adapter)
    allow(stripe_adapter).to receive(:charge).and_return(successful_charge_result)
    REDIS.del("idempotency:#{merchant.id}:#{idempotency_key}")
  end

  after do
    REDIS.del("idempotency:#{merchant.id}:#{idempotency_key}")
  end

  describe "#call" do
    it "creates a charge and returns a Result" do
      result = described_class.new(**default_params).call

      expect(result.charge).to be_a(Charge)
      expect(result.replayed).to be(false)
      expect(result.charge.status).to eq("captured")
      expect(result.charge.provider_charge_id).to eq("pi_test_123")
      expect(result.charge.merchant_id).to eq(merchant.id)
    end

    it "routes card payments through StripeAdapter" do
      described_class.new(**default_params).call

      expect(PaymentRouterService).to have_received(:for)
        .with(payment_method: "card", environment: "sandbox")
    end

    it "routes mada payments through CheckoutAdapter" do
      checkout_adapter = instance_double(Adapters::CheckoutAdapter)
      allow(PaymentRouterService).to receive(:for)
        .with(payment_method: "mada", environment: "sandbox")
        .and_return(checkout_adapter)
      allow(checkout_adapter).to receive(:charge).and_return(successful_charge_result)

      params = default_params.merge(payment_method: "mada", token: "tok_mada")
      described_class.new(**params).call

      expect(checkout_adapter).to have_received(:charge)
    end

    context "with idempotency replay" do
      it "returns the cached charge without hitting the adapter again" do
        first_result = described_class.new(**default_params).call
        first_charge  = first_result.charge

        second_result = described_class.new(**default_params).call

        expect(second_result.charge.id).to eq(first_charge.id)
        expect(second_result.replayed).to be(true)
        expect(stripe_adapter).to have_received(:charge).once
      end
    end

    context "when payment method is disabled for merchant" do
      let(:merchant) { create(:merchant, enabled_payment_methods: %w[card]) }

      it "raises PaygateError without creating a charge" do
        params = default_params.merge(payment_method: "mada", token: "tok_mada")

        expect {
          described_class.new(**params).call
        }.to raise_error(PaygateError) { |e|
          expect(e.code).to eq("payment_method_disabled")
        }

        expect(Charge.count).to eq(0)
      end
    end

    context "when adapter returns a failure" do
      let(:failed_result) do
        Adapters::BaseAdapter::ChargeResult.new(
          provider_charge_id: "pi_test_failed",
          status: "failed",
          failure_code: "card_declined",
          failure_message: "Your card was declined."
        )
      end

      before { allow(stripe_adapter).to receive(:charge).and_return(failed_result) }

      it "creates a failed charge and stores idempotency key" do
        result = described_class.new(**default_params).call

        expect(result.charge.status).to eq("failed")
        expect(result.charge.failure_code).to eq("card_declined")

        cached = REDIS.get("idempotency:#{merchant.id}:#{idempotency_key}")
        expect(cached).to eq(result.charge.id)
      end
    end

    context "when merchant environment is live" do
      let(:merchant) { create(:merchant, environment: "live") }

      it "raises PaygateError with live_mode_disabled code" do
        expect {
          described_class.new(**default_params).call
        }.to raise_error(PaygateError) { |e|
          expect(e.code).to eq("live_mode_disabled")
          expect(e.status).to eq(:forbidden)
        }
      end
    end
  end
end
