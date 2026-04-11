require "swagger_helper"

RSpec.describe "Webhooks", type: :request do
  path "/v1/webhooks/verify" do
    post "Verify a webhook signature" do
      tags "Webhooks"
      consumes "application/json"
      produces "application/json"
      parameter name: :Authorization, in: :header, schema: { type: :string }, required: true
      parameter name: :body, in: :body, required: true, schema: {
        "$ref" => "#/components/schemas/VerifyWebhookRequest"
      }

      response "200", "signature verification result" do
        schema type: :object,
          required: %w[valid],
          properties: {
            valid: { type: :boolean },
            message: { type: :string, nullable: true }
          }

        let(:merchant)    { create(:merchant, environment: "sandbox", enabled_payment_methods: %w[card]) }
        let(:api_key_rec) { create(:api_key, merchant: merchant, environment: "sandbox") }
        let(:endpoint)    { create(:webhook_endpoint, merchant: merchant) }
        let(:raw_payload) { '{"event_type":"charge.captured","data":{}}' }
        let(:Authorization) { "Bearer sk_test_#{SecureRandom.alphanumeric(32).downcase}" }
        let(:body) do
          {
            endpoint_id: endpoint.id,
            payload: raw_payload,
            signature: "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', endpoint.webhook_secret, raw_payload)}"
          }
        end

        before do
          allow(ApiKeyService).to receive(:authenticate).and_return(api_key_rec)
          allow(api_key_rec).to receive(:merchant).and_return(merchant)
        end

        run_test!
      end

      response "404", "endpoint not found or belongs to another merchant" do
        schema "$ref" => "#/components/schemas/Error"

        let(:merchant)    { create(:merchant, environment: "sandbox", enabled_payment_methods: %w[card]) }
        let(:api_key_rec) { create(:api_key, merchant: merchant, environment: "sandbox") }
        let(:Authorization) { "Bearer sk_test_#{SecureRandom.alphanumeric(32).downcase}" }
        let(:body) do
          { endpoint_id: SecureRandom.uuid, payload: "{}", signature: "sha256=bad" }
        end

        before do
          allow(ApiKeyService).to receive(:authenticate).and_return(api_key_rec)
          allow(api_key_rec).to receive(:merchant).and_return(merchant)
        end

        run_test!
      end

      response "401", "unauthorized" do
        schema "$ref" => "#/components/schemas/Error"

        let(:Authorization) { "Bearer bad_key" }
        let(:body) { { endpoint_id: SecureRandom.uuid, payload: "{}", signature: "sha256=bad" } }
        run_test!
      end
    end
  end
end
