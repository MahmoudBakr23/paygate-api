require "rails_helper"

RSpec.describe IdempotencyService do
  let(:merchant_id)     { SecureRandom.uuid }
  let(:idempotency_key) { SecureRandom.uuid }
  let(:service)         { described_class.new(merchant_id: merchant_id, idempotency_key: idempotency_key) }

  before { REDIS.del("idempotency:#{merchant_id}:#{idempotency_key}") }
  after  { REDIS.del("idempotency:#{merchant_id}:#{idempotency_key}") }

  describe "#cached_charge_id" do
    it "returns nil when no key is stored" do
      expect(service.cached_charge_id).to be_nil
    end

    it "returns the stored charge_id after storing" do
      charge_id = SecureRandom.uuid
      service.store!(charge_id)
      expect(service.cached_charge_id).to eq(charge_id)
    end
  end

  describe "#store!" do
    it "persists the charge_id in Redis with 24h TTL" do
      charge_id = SecureRandom.uuid
      service.store!(charge_id)

      ttl = REDIS.ttl("idempotency:#{merchant_id}:#{idempotency_key}")
      expect(ttl).to be_within(5).of(IdempotencyService::TTL)
    end
  end

  describe ".require_key!" do
    let(:request) { instance_double(ActionDispatch::Request) }

    it "returns the key when Idempotency-Key header is present" do
      allow(request).to receive(:headers).and_return({ "Idempotency-Key" => "my-key-123" })

      expect(described_class.require_key!(request)).to eq("my-key-123")
    end

    it "raises PaygateError when header is missing" do
      allow(request).to receive(:headers).and_return({})

      expect {
        described_class.require_key!(request)
      }.to raise_error(PaygateError) { |e|
        expect(e.code).to eq("missing_idempotency_key")
        expect(e.status).to eq(:unprocessable_content)
      }
    end
  end
end
