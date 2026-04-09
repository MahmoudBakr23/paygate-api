require "rails_helper"

RSpec.describe "Merchant profile (/v1/me)" do
  let!(:merchant) { create(:merchant) }
  let(:token) { AuthService.new.login(email: merchant.email, password: "Password1!").token }
  let(:headers) { auth_headers(token) }

  describe "GET /v1/me" do
    it "returns the merchant profile" do
      get "/v1/me", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response[:id]).to eq(merchant.id)
      expect(json_response[:email]).to eq(merchant.email)
    end

    it "returns 401 without a token" do
      get "/v1/me", as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "accepts API key authentication" do
      raw_secret = "sk_test_#{SecureRandom.alphanumeric(32).downcase}"
      create(:api_key, merchant: merchant,
             secret_key_digest: BCrypt::Password.create(raw_secret),
             key_prefix: raw_secret.first(ApiKeyService::KEY_PREFIX_LENGTH))

      get "/v1/me", headers: auth_headers(raw_secret), as: :json
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /v1/me" do
    it "updates allowed fields" do
      patch "/v1/me", params: { name: "New Name", webhook_url: "https://example.com/webhook" },
                      headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response[:name]).to eq("New Name")
      expect(json_response[:webhook_url]).to eq("https://example.com/webhook")
    end

    it "can update enabled_payment_methods" do
      patch "/v1/me", params: { enabled_payment_methods: ["card"] },
                      headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response[:enabled_payment_methods]).to eq(["card"])
    end

    it "returns 401 without a token" do
      patch "/v1/me", params: { name: "Hacker" }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
