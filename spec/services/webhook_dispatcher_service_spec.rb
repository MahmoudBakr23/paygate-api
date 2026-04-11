require "rails_helper"

RSpec.describe WebhookDispatcherService do
  let(:merchant)  { create(:merchant, environment: "sandbox", enabled_payment_methods: %w[card]) }
  let(:charge)    { create(:charge, :captured, merchant: merchant) }
  let!(:endpoint) { create(:webhook_endpoint, merchant: merchant, events: %w[charge.captured charge.failed]) }

  before { allow(WebhookDeliveryJob).to receive(:perform_later) }

  describe ".dispatch" do
    context "when the endpoint subscribes to the event" do
      it "creates a WebhookDelivery and enqueues the job" do
        expect {
          described_class.dispatch(event_type: "charge.captured", charge: charge, refund: nil, merchant: merchant)
        }.to change(WebhookDelivery, :count).by(1)

        expect(WebhookDeliveryJob).to have_received(:perform_later)
      end

      it "sets the correct event_type on the delivery" do
        described_class.dispatch(event_type: "charge.captured", charge: charge, refund: nil, merchant: merchant)
        delivery = WebhookDelivery.last
        expect(delivery.event_type).to eq("charge.captured")
        expect(delivery.status).to eq("pending")
      end

      it "includes charge data in the payload" do
        described_class.dispatch(event_type: "charge.captured", charge: charge, refund: nil, merchant: merchant)
        payload = WebhookDelivery.last.payload
        expect(payload["event_type"]).to eq("charge.captured")
        expect(payload["data"]["charge"]["id"]).to eq(charge.id)
      end
    end

    context "when the endpoint does NOT subscribe to the event" do
      it "creates no delivery and does not enqueue a job" do
        expect {
          described_class.dispatch(event_type: "charge.voided", charge: charge, refund: nil, merchant: merchant)
        }.not_to change(WebhookDelivery, :count)

        expect(WebhookDeliveryJob).not_to have_received(:perform_later)
      end
    end

    context "when the endpoint is inactive" do
      before { endpoint.update!(active: false) }

      it "creates no delivery" do
        expect {
          described_class.dispatch(event_type: "charge.captured", charge: charge, refund: nil, merchant: merchant)
        }.not_to change(WebhookDelivery, :count)
      end
    end

    context "with a refund event" do
      let(:refund) { create(:refund, charge_id: charge.id, merchant: merchant, amount: 500, status: "succeeded") }
      let!(:refund_endpoint) { create(:webhook_endpoint, merchant: merchant, events: %w[refund.created refund.succeeded]) }

      it "includes refund data in the payload" do
        described_class.dispatch(event_type: "refund.succeeded", charge: charge, refund: refund, merchant: merchant)
        payload = WebhookDelivery.last.payload
        expect(payload["data"]["object"]).to eq("refund")
        expect(payload["data"]["refund"]["id"]).to eq(refund.id)
      end
    end

    context "when no endpoints exist for the merchant" do
      before { endpoint.destroy }

      it "does nothing" do
        expect {
          described_class.dispatch(event_type: "charge.captured", charge: charge, refund: nil, merchant: merchant)
        }.not_to change(WebhookDelivery, :count)
      end
    end
  end
end
