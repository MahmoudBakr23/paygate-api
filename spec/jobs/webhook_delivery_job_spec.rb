require "rails_helper"

RSpec.describe WebhookDeliveryJob do
  let(:endpoint) { create(:webhook_endpoint, url: "https://example.com/hook", webhook_secret: "whsec_testsecret") }
  let(:delivery) { create(:webhook_delivery, webhook_endpoint: endpoint, status: "pending", attempts: 0) }

  let(:http_double)     { instance_double(Net::HTTP) }
  let(:response_double) { instance_double(Net::HTTPResponse) }

  before do
    allow(Net::HTTP).to receive(:start).and_yield(http_double)
    allow(http_double).to receive(:request).and_return(response_double)
  end

  describe "#perform" do
    context "when delivery is missing" do
      it "returns without error" do
        expect { described_class.new.perform("nonexistent-id") }.not_to raise_error
      end
    end

    context "when endpoint is inactive" do
      before { endpoint.update!(active: false) }

      it "returns without making an HTTP request" do
        described_class.new.perform(delivery.id)
        expect(http_double).not_to have_received(:request)
      end
    end

    context "when the endpoint returns 2xx" do
      before { allow(response_double).to receive(:code).and_return("200") }

      it "marks the delivery as delivered" do
        described_class.new.perform(delivery.id)
        delivery.reload
        expect(delivery.status).to eq("delivered")
        expect(delivery.http_status).to eq(200)
        expect(delivery.attempts).to eq(1)
        expect(delivery.delivered_at).not_to be_nil
      end
    end

    context "when the endpoint returns 5xx and attempts < MAX_ATTEMPTS" do
      before { allow(response_double).to receive(:code).and_return("500") }

      it "marks the delivery as retrying and schedules a retry" do
        allow(described_class).to receive(:set).and_return(described_class)
        allow(described_class).to receive(:perform_later)

        described_class.new.perform(delivery.id)
        delivery.reload

        expect(delivery.status).to eq("retrying")
        expect(delivery.attempts).to eq(1)
        expect(delivery.next_retry_at).not_to be_nil
        expect(described_class).to have_received(:perform_later).with(delivery.id)
      end
    end

    context "when attempts reach MAX_ATTEMPTS" do
      let(:delivery) { create(:webhook_delivery, webhook_endpoint: endpoint, status: "retrying", attempts: 4) }

      before { allow(response_double).to receive(:code).and_return("500") }

      it "marks the delivery as failed" do
        described_class.new.perform(delivery.id)
        delivery.reload
        expect(delivery.status).to eq("failed")
        expect(delivery.attempts).to eq(5)
      end
    end

    context "when the HTTP request raises an error" do
      before { allow(http_double).to receive(:request).and_raise(Net::ReadTimeout) }

      it "marks the delivery as retrying" do
        allow(described_class).to receive(:set).and_return(described_class)
        allow(described_class).to receive(:perform_later)

        described_class.new.perform(delivery.id)
        delivery.reload
        expect(delivery.status).to eq("retrying")
      end
    end

    it "sends the correct headers including HMAC signature" do
      allow(response_double).to receive(:code).and_return("200")
      sent_request = nil
      allow(http_double).to receive(:request) { |req| sent_request = req; response_double }

      described_class.new.perform(delivery.id)

      expect(sent_request["Content-Type"]).to eq("application/json")
      expect(sent_request["X-PayGate-Signature"]).to match(/\Asha256=[0-9a-f]{64}\z/)
      expect(sent_request["X-PayGate-Event"]).to eq(delivery.event_type)
      expect(sent_request["X-PayGate-Delivery"]).to eq(delivery.id)
    end
  end
end
