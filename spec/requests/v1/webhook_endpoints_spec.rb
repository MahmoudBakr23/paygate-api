require "rails_helper"

RSpec.describe "Webhook Endpoints (/v1/me/webhook_endpoints)" do
  let!(:merchant) { create(:merchant) }
  let(:token) { AuthService.new.login(email: merchant.email, password: "Password1!").token }
  let(:headers) { auth_headers(token) }

  describe "GET /v1/me/webhook_endpoints" do
    before { create_list(:webhook_endpoint, 2, merchant: merchant) }

    it "returns all webhook endpoints for the merchant" do
      get "/v1/me/webhook_endpoints", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response.length).to eq(2)
      expect(json_response.first[:url]).to be_present
      expect(json_response.first[:events]).to be_present
    end

    it "does not return endpoints belonging to another merchant" do
      create(:webhook_endpoint)
      get "/v1/me/webhook_endpoints", headers: headers, as: :json

      expect(json_response.length).to eq(2)
    end

    it "returns 401 without a token" do
      get "/v1/me/webhook_endpoints", as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /v1/me/webhook_endpoints" do
    let(:valid_params) do
      { url: "https://merchant.example.com/hooks", events: %w[charge.captured charge.failed] }
    end

    it "creates a webhook endpoint and returns the secret once" do
      post "/v1/me/webhook_endpoints", params: valid_params, headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response[:webhook_endpoint][:url]).to eq("https://merchant.example.com/hooks")
      expect(json_response[:webhook_secret]).to start_with("whsec_")
    end

    it "returns 422 for an invalid URL" do
      post "/v1/me/webhook_endpoints",
           params: { url: "not-a-url", events: %w[charge.captured] },
           headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 422 for invalid event types" do
      post "/v1/me/webhook_endpoints",
           params: { url: "https://example.com/hooks", events: %w[invalid.event] },
           headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 401 without a token" do
      post "/v1/me/webhook_endpoints", params: valid_params, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /v1/me/webhook_endpoints/:id" do
    let!(:endpoint) { create(:webhook_endpoint, merchant: merchant) }

    it "updates the endpoint" do
      patch "/v1/me/webhook_endpoints/#{endpoint.id}",
            params: { active: false },
            headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response[:active]).to eq(false)
    end

    it "returns 404 for another merchant's endpoint" do
      other_endpoint = create(:webhook_endpoint)
      patch "/v1/me/webhook_endpoints/#{other_endpoint.id}",
            params: { active: false },
            headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 without a token" do
      patch "/v1/me/webhook_endpoints/#{endpoint.id}", params: { active: false }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /v1/me/webhook_endpoints/:id" do
    let!(:endpoint) { create(:webhook_endpoint, merchant: merchant) }

    it "removes the endpoint" do
      delete "/v1/me/webhook_endpoints/#{endpoint.id}", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response[:message]).to eq("Webhook endpoint removed")
      expect(WebhookEndpoint.find_by(id: endpoint.id)).to be_nil
    end

    it "returns 404 for another merchant's endpoint" do
      other_endpoint = create(:webhook_endpoint)
      delete "/v1/me/webhook_endpoints/#{other_endpoint.id}", headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 without a token" do
      delete "/v1/me/webhook_endpoints/#{endpoint.id}", as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
