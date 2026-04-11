require "rails_helper"

RSpec.describe "Inbound provider webhooks", type: :request do
  describe "POST /webhooks/stripe" do
    it "enqueues ProviderWebhookProcessorJob and returns 200" do
      allow(ProviderWebhookProcessorJob).to receive(:perform_later)

      post "/webhooks/stripe",
        params: '{"type":"payment_intent.succeeded"}',
        headers: {
          "Content-Type"     => "application/json",
          "Stripe-Signature" => "t=12345,v1=fakehash"
        }

      expect(response).to have_http_status(:ok)
      expect(ProviderWebhookProcessorJob).to have_received(:perform_later).with(
        "stripe",
        '{"type":"payment_intent.succeeded"}',
        "t=12345,v1=fakehash"
      )
    end
  end

  describe "POST /webhooks/checkout" do
    it "enqueues ProviderWebhookProcessorJob and returns 200" do
      allow(ProviderWebhookProcessorJob).to receive(:perform_later)

      post "/webhooks/checkout",
        params: '{"type":"payment_approved"}',
        headers: {
          "Content-Type"  => "application/json",
          "Cko-Signature" => "fakehash"
        }

      expect(response).to have_http_status(:ok)
      expect(ProviderWebhookProcessorJob).to have_received(:perform_later).with(
        "checkout",
        '{"type":"payment_approved"}',
        "fakehash"
      )
    end
  end
end
