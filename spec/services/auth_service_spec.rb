require "rails_helper"

RSpec.describe AuthService do
  subject(:service) { described_class.new }

  describe "#register" do
    let(:valid_params) { { name: "Acme Inc", email: "acme@example.com", password: "Password1!" } }

    it "creates a merchant" do
      expect { service.register(**valid_params) }.to change(Merchant, :count).by(1)
    end

    it "auto-generates a sandbox API key pair" do
      expect { service.register(**valid_params) }.to change(ApiKey, :count).by(1)
    end

    it "returns a register result with token, merchant, and sandbox key pair" do
      result = service.register(**valid_params)

      expect(result.token).to be_present
      expect(result.merchant.email).to eq("acme@example.com")
      expect(result.api_key_result.public_key).to start_with("pk_test_")
      expect(result.api_key_result.secret_key).to start_with("sk_test_")
    end

    it "downcases email" do
      result = service.register(**valid_params.merge(email: "ACME@EXAMPLE.COM"))
      expect(result.merchant.email).to eq("acme@example.com")
    end

    it "raises RecordInvalid when email already taken" do
      service.register(**valid_params)
      expect { service.register(**valid_params) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "raises RecordInvalid on blank name" do
      expect { service.register(**valid_params.merge(name: "")) }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe "#login" do
    let!(:merchant) { create(:merchant, email: "test@example.com", password: "Password1!") }

    it "returns a login result with a JWT token" do
      result = service.login(email: "test@example.com", password: "Password1!")
      expect(result.token).to be_present
      expect(result.merchant).to eq(merchant)
    end

    it "is case-insensitive for email" do
      result = service.login(email: "TEST@EXAMPLE.COM", password: "Password1!")
      expect(result.merchant).to eq(merchant)
    end

    it "raises AuthenticationError on wrong password" do
      expect {
        service.login(email: "test@example.com", password: "wrong")
      }.to raise_error(AuthService::AuthenticationError)
    end

    it "raises AuthenticationError on unknown email" do
      expect {
        service.login(email: "nobody@example.com", password: "Password1!")
      }.to raise_error(AuthService::AuthenticationError)
    end
  end

  describe "#verify_token" do
    let!(:merchant) { create(:merchant) }

    it "returns the merchant from a valid token" do
      token = service.login(email: merchant.email, password: "Password1!").token
      result = service.verify_token(token: token)
      expect(result.merchant).to eq(merchant)
    end

    it "raises InvalidTokenError for a garbage string" do
      expect { service.verify_token(token: "notavalidtoken") }
        .to raise_error(AuthService::InvalidTokenError)
    end

    it "raises InvalidTokenError for a revoked token" do
      result = service.login(email: merchant.email, password: "Password1!")
      verify = service.verify_token(token: result.token)
      service.revoke_token(jti: verify.jti, exp: verify.exp)

      expect { service.verify_token(token: result.token) }
        .to raise_error(AuthService::InvalidTokenError, /revoked/)
    end
  end

  describe "#revoke_token" do
    let!(:merchant) { create(:merchant) }

    it "writes the JTI to Redis so subsequent verify calls fail" do
      result = service.login(email: merchant.email, password: "Password1!")
      verify = service.verify_token(token: result.token)
      service.revoke_token(jti: verify.jti, exp: verify.exp)

      expect(REDIS.exists?("jwt:revoked:#{verify.jti}")).to be_truthy
    end
  end
end
