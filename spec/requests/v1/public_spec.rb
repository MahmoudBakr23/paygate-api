require "rails_helper"

RSpec.describe "V1::Public", type: :request do
  describe "GET /v1/public/config" do
    let(:api_key) { create(:api_key) }

    context "with a valid active public key" do
      it "returns 200 without an auth header" do
        get "/v1/public/config", params: { public_key: api_key.public_key }

        expect(response).to have_http_status(:ok)
      end

      it "returns the expected top-level keys" do
        get "/v1/public/config", params: { public_key: api_key.public_key }

        body = json_response
        expect(body).to include(:stripe_publishable_key, :supported_methods, :environment)
      end

      it "returns supported_methods containing card, apple_pay, and mada" do
        get "/v1/public/config", params: { public_key: api_key.public_key }

        expect(json_response[:supported_methods]).to contain_exactly("card", "apple_pay", "mada")
      end

      it "returns environment as sandbox" do
        get "/v1/public/config", params: { public_key: api_key.public_key }

        expect(json_response[:environment]).to eq("sandbox")
      end

      it "returns the stripe publishable key from ENV" do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with("STRIPE_SANDBOX_PUBLISHABLE_KEY", nil).and_return("pk_test_example")

        get "/v1/public/config", params: { public_key: api_key.public_key }

        expect(json_response[:stripe_publishable_key]).to eq("pk_test_example")
      end
    end

    context "with a revoked public key" do
      let(:api_key) { create(:api_key, :revoked) }

      it "returns 404" do
        get "/v1/public/config", params: { public_key: api_key.public_key }

        expect(response).to have_http_status(:not_found)
      end
    end

    context "with an unknown public key" do
      it "returns 404" do
        get "/v1/public/config", params: { public_key: "pk_test_doesnotexist" }

        expect(response).to have_http_status(:not_found)
      end
    end

    context "with no public key" do
      it "returns 404" do
        get "/v1/public/config"

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
