require "rails_helper"

RSpec.describe "V1::Webhooks", type: :request do
  let(:merchant)    { create(:merchant, environment: "sandbox", enabled_payment_methods: %w[card]) }
  let(:api_key_rec) { create(:api_key, merchant: merchant, environment: "sandbox") }
  let(:secret_key)  { "sk_test_#{SecureRandom.alphanumeric(32).downcase}" }
  let(:headers) do
    {
      "Authorization" => "Bearer #{secret_key}",
      "Content-Type"  => "application/json"
    }
  end

  before do
    allow(ApiKeyService).to receive(:authenticate).and_return(api_key_rec)
    allow(api_key_rec).to receive(:merchant).and_return(merchant)
  end

  describe "POST /v1/webhooks/verify" do
    let(:endpoint) { create(:webhook_endpoint, merchant: merchant) }
    let(:raw_payload) { '{"event_type":"charge.captured","data":{}}' }
    let(:valid_signature) do
      "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', endpoint.webhook_secret, raw_payload)}"
    end

    context "with a valid signature" do
      it "returns { valid: true }" do
        post "/v1/webhooks/verify",
          params: { endpoint_id: endpoint.id, payload: raw_payload, signature: valid_signature }.to_json,
          headers: headers

        expect(response).to have_http_status(:ok)
        expect(json_response[:valid]).to be(true)
      end
    end

    context "with an invalid signature" do
      it "returns { valid: false }" do
        post "/v1/webhooks/verify",
          params: { endpoint_id: endpoint.id, payload: raw_payload, signature: "sha256=badhash" }.to_json,
          headers: headers

        expect(response).to have_http_status(:ok)
        expect(json_response[:valid]).to be(false)
      end
    end

    context "when endpoint does not belong to the merchant" do
      let(:other_endpoint) do
        m = create(:merchant, environment: "sandbox", enabled_payment_methods: %w[card])
        create(:webhook_endpoint, merchant: m)
      end

      it "returns 404" do
        post "/v1/webhooks/verify",
          params: { endpoint_id: other_endpoint.id, payload: raw_payload, signature: valid_signature }.to_json,
          headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context "without authentication" do
      it "returns 401" do
        post "/v1/webhooks/verify",
          params: { endpoint_id: endpoint.id, payload: raw_payload, signature: valid_signature }.to_json,
          headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
