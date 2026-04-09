require "rails_helper"

RSpec.describe "API Keys (/v1/me/api_keys)" do
  let!(:merchant) { create(:merchant) }
  let(:token) { AuthService.new.login(email: merchant.email, password: "Password1!").token }
  let(:headers) { auth_headers(token) }

  describe "GET /v1/me/api_keys" do
    before { create_list(:api_key, 2, merchant: merchant) }

    it "returns active keys for the merchant" do
      get "/v1/me/api_keys", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response.length).to eq(2)
      expect(json_response.map { _1[:environment] }).to all(eq("sandbox"))
    end

    it "excludes revoked keys" do
      create(:api_key, :revoked, merchant: merchant)
      get "/v1/me/api_keys", headers: headers, as: :json

      expect(json_response.length).to eq(2)
    end

    it "returns 401 without a token" do
      get "/v1/me/api_keys", as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /v1/me/api_keys" do
    it "generates a new sandbox key pair and shows the secret once" do
      post "/v1/me/api_keys", params: { environment: "sandbox" }, headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response[:public_key]).to start_with("pk_test_")
      expect(json_response[:secret_key]).to start_with("sk_test_")
      expect(json_response[:api_key][:id]).to be_present
    end

    it "generates a live key pair" do
      post "/v1/me/api_keys", params: { environment: "live" }, headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response[:public_key]).to start_with("pk_live_")
      expect(json_response[:secret_key]).to start_with("sk_live_")
    end

    it "defaults to sandbox when no environment given" do
      post "/v1/me/api_keys", headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response[:public_key]).to start_with("pk_test_")
    end

    it "returns 422 on invalid environment" do
      post "/v1/me/api_keys", params: { environment: "staging" }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /v1/me/api_keys/:id" do
    let!(:api_key) { create(:api_key, merchant: merchant) }

    it "revokes the key and returns 200" do
      delete "/v1/me/api_keys/#{api_key.id}", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(api_key.reload.revoked_at).to be_present
    end

    it "returns 404 for a non-existent key" do
      delete "/v1/me/api_keys/#{SecureRandom.uuid}", headers: headers, as: :json
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for another merchant's key" do
      other_key = create(:api_key)
      delete "/v1/me/api_keys/#{other_key.id}", headers: headers, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end
end
