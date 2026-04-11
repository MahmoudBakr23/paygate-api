require "rails_helper"

RSpec.describe ProviderWebhookProcessorJob do
  let(:merchant) { create(:merchant, environment: "sandbox", enabled_payment_methods: %w[card]) }
  let(:charge)   { create(:charge, :authorized, merchant: merchant, provider_charge_id: "pi_test_stripe_123") }

  before do
    allow(WebhookDispatcherService).to receive(:dispatch)
    allow(LedgerService).to receive(:record_captured_charge)
  end

  describe "#perform with stripe" do
    let(:stripe_secret) { "stripe_webhook_secret" }

    before { allow(ENV).to receive(:fetch).with("STRIPE_SANDBOX_WEBHOOK_SECRET", nil).and_return(stripe_secret) }

    def build_signed_payload(event_hash, secret)
      payload_json = event_hash.to_json
      timestamp    = Time.current.to_i.to_s
      signed_str   = "#{timestamp}.#{payload_json}"
      hmac         = OpenSSL::HMAC.hexdigest("SHA256", secret, signed_str)
      signature    = "t=#{timestamp},v1=#{hmac}"
      [ payload_json, signature ]
    end

    context "when signature is invalid" do
      it "logs a warning and does nothing" do
        described_class.new.perform("stripe", '{"type":"payment_intent.succeeded"}', "bad_sig")
        expect(WebhookDispatcherService).not_to have_received(:dispatch)
      end
    end

    context "payment_intent.succeeded for an authorized charge" do
      it "transitions to captured and dispatches charge.captured" do
        event = { "type" => "payment_intent.succeeded", "data" => { "object" => { "id" => charge.provider_charge_id } } }
        payload_json, signature = build_signed_payload(event, stripe_secret)

        described_class.new.perform("stripe", payload_json, signature)

        charge.reload
        expect(charge.status).to eq("captured")
        expect(WebhookDispatcherService).to have_received(:dispatch).with(
          hash_including(event_type: "charge.captured", merchant: merchant)
        )
      end
    end

    context "payment_intent.succeeded for an already-captured charge" do
      let(:charge) { create(:charge, :captured, merchant: merchant, provider_charge_id: "pi_test_stripe_123") }

      it "is idempotent — does not re-capture" do
        event = { "type" => "payment_intent.succeeded", "data" => { "object" => { "id" => charge.provider_charge_id } } }
        payload_json, signature = build_signed_payload(event, stripe_secret)

        allow(LedgerService).to receive(:record_captured_charge)
        described_class.new.perform("stripe", payload_json, signature)
        expect(LedgerService).not_to have_received(:record_captured_charge)
      end
    end

    context "payment_intent.payment_failed" do
      it "transitions charge to failed and dispatches charge.failed" do
        event = { "type" => "payment_intent.payment_failed", "data" => { "object" => { "id" => charge.provider_charge_id } } }
        payload_json, signature = build_signed_payload(event, stripe_secret)

        described_class.new.perform("stripe", payload_json, signature)

        charge.reload
        expect(charge.status).to eq("failed")
        expect(WebhookDispatcherService).to have_received(:dispatch).with(
          hash_including(event_type: "charge.failed")
        )
      end
    end

    context "when charge is not found" do
      it "does nothing without raising" do
        event = { "type" => "payment_intent.succeeded", "data" => { "object" => { "id" => "pi_nonexistent" } } }
        payload_json, signature = build_signed_payload(event, stripe_secret)

        expect { described_class.new.perform("stripe", payload_json, signature) }.not_to raise_error
        expect(WebhookDispatcherService).not_to have_received(:dispatch)
      end
    end

    context "unhandled event type" do
      it "logs and does nothing" do
        event = { "type" => "customer.created", "data" => { "object" => {} } }
        payload_json, signature = build_signed_payload(event, stripe_secret)

        expect { described_class.new.perform("stripe", payload_json, signature) }.not_to raise_error
        expect(WebhookDispatcherService).not_to have_received(:dispatch)
      end
    end
  end

  describe "#perform with unknown provider" do
    it "logs a warning and does nothing" do
      expect { described_class.new.perform("unknown_provider", "{}", "sig") }.not_to raise_error
      expect(WebhookDispatcherService).not_to have_received(:dispatch)
    end
  end
end
