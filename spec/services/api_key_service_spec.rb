require "rails_helper"

RSpec.describe ApiKeyService do
  let(:merchant) { create(:merchant) }
  subject(:service) { described_class.new(merchant: merchant) }

  describe "#generate_pair" do
    it "creates an ApiKey record" do
      expect { service.generate_pair(environment: "sandbox") }.to change(ApiKey, :count).by(1)
    end

    it "returns the plaintext public and secret keys" do
      result = service.generate_pair(environment: "sandbox")
      expect(result.public_key).to match(/\Apk_test_[a-z0-9]{32}\z/)
      expect(result.secret_key).to match(/\Ask_test_[a-z0-9]{32}\z/)
    end

    it "stores a bcrypt digest, not the plaintext secret key" do
      result = service.generate_pair(environment: "sandbox")
      stored_digest = result.api_key.secret_key_digest
      expect(stored_digest).not_to eq(result.secret_key)
      expect(BCrypt::Password.new(stored_digest)).to eq(result.secret_key)
    end

    it "stores the correct key_prefix" do
      result = service.generate_pair(environment: "sandbox")
      expect(result.api_key.key_prefix).to eq(result.secret_key.first(ApiKeyService::KEY_PREFIX_LENGTH))
    end

    context "for live environment" do
      it "uses live key prefixes" do
        result = service.generate_pair(environment: "live")
        expect(result.public_key).to start_with("pk_live_")
        expect(result.secret_key).to start_with("sk_live_")
      end
    end
  end

  describe "#revoke" do
    let!(:api_key) { create(:api_key, merchant: merchant) }

    it "sets revoked_at on the key" do
      expect { service.revoke(api_key: api_key) }
        .to change { api_key.reload.revoked_at }.from(nil)
    end

    it "raises ArgumentError when key belongs to a different merchant" do
      other_key = create(:api_key)
      expect { service.revoke(api_key: other_key) }.to raise_error(ArgumentError)
    end
  end

  describe ".authenticate" do
    let(:raw_secret) { "sk_test_#{SecureRandom.alphanumeric(32).downcase}" }
    let!(:api_key) do
      ApiKey.create!(
        merchant: merchant,
        environment: "sandbox",
        public_key: "pk_test_#{SecureRandom.alphanumeric(32).downcase}",
        secret_key_digest: BCrypt::Password.create(raw_secret),
        key_prefix: raw_secret.first(ApiKeyService::KEY_PREFIX_LENGTH)
      )
    end

    it "returns the api_key for a valid secret key" do
      result = described_class.authenticate(raw_key: raw_secret)
      expect(result).to eq(api_key)
    end

    it "updates last_used_at" do
      expect { described_class.authenticate(raw_key: raw_secret) }
        .to change { api_key.reload.last_used_at }
    end

    it "returns nil for a wrong key" do
      expect(described_class.authenticate(raw_key: "sk_test_#{SecureRandom.alphanumeric(32).downcase}")).to be_nil
    end

    it "returns nil for a revoked key" do
      api_key.revoke!
      expect(described_class.authenticate(raw_key: raw_secret)).to be_nil
    end

    it "returns nil for a malformed token" do
      expect(described_class.authenticate(raw_key: "Bearer garbage")).to be_nil
      expect(described_class.authenticate(raw_key: nil)).to be_nil
    end
  end
end
