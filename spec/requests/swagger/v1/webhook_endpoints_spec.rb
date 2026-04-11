require "swagger_helper"

RSpec.describe "Webhook Endpoints", type: :request do
  path "/v1/me/webhook_endpoints" do
    get "List webhook endpoints" do
      tags "Webhooks"
      produces "application/json"
      parameter name: :Authorization, in: :header, schema: { type: :string }, required: true

      response "200", "list of webhook endpoints" do
        schema type: :array, items: { "$ref" => "#/components/schemas/WebhookEndpoint" }

        let(:merchant) { create(:merchant) }
        let(:Authorization) do
          "Bearer #{AuthService.new.login(email: merchant.email, password: 'Password1!').token}"
        end
        before { create_list(:webhook_endpoint, 2, merchant: merchant) }
        run_test!
      end

      response "401", "unauthorized" do
        schema "$ref" => "#/components/schemas/Error"
        let(:Authorization) { "Bearer bad_token" }
        run_test!
      end
    end

    post "Register a webhook endpoint" do
      tags "Webhooks"
      consumes "application/json"
      produces "application/json"
      parameter name: :Authorization, in: :header, schema: { type: :string }, required: true
      parameter name: :body, in: :body, required: true, schema: {
        "$ref" => "#/components/schemas/CreateWebhookEndpointRequest"
      }

      response "201", "endpoint created — webhook_secret shown once" do
        schema "$ref" => "#/components/schemas/WebhookEndpointCreated"

        let(:merchant) { create(:merchant) }
        let(:Authorization) do
          "Bearer #{AuthService.new.login(email: merchant.email, password: 'Password1!').token}"
        end
        let(:body) do
          { url: "https://merchant.example.com/hooks", events: %w[charge.captured charge.failed] }
        end
        run_test!
      end

      response "422", "invalid URL or event type" do
        schema "$ref" => "#/components/schemas/Error"

        let(:merchant) { create(:merchant) }
        let(:Authorization) do
          "Bearer #{AuthService.new.login(email: merchant.email, password: 'Password1!').token}"
        end
        let(:body) { { url: "not-a-url", events: %w[charge.captured] } }
        run_test!
      end

      response "401", "unauthorized" do
        schema "$ref" => "#/components/schemas/Error"
        let(:Authorization) { "Bearer bad_token" }
        let(:body) { { url: "https://example.com", events: [] } }
        run_test!
      end
    end
  end

  path "/v1/me/webhook_endpoints/{id}" do
    parameter name: :id, in: :path, type: :string, required: true

    patch "Update a webhook endpoint" do
      tags "Webhooks"
      consumes "application/json"
      produces "application/json"
      parameter name: :Authorization, in: :header, schema: { type: :string }, required: true
      parameter name: :body, in: :body, required: true, schema: {
        "$ref" => "#/components/schemas/UpdateWebhookEndpointRequest"
      }

      response "200", "endpoint updated" do
        schema "$ref" => "#/components/schemas/WebhookEndpoint"

        let(:merchant) { create(:merchant) }
        let(:endpoint) { create(:webhook_endpoint, merchant: merchant) }
        let(:id) { endpoint.id }
        let(:Authorization) do
          "Bearer #{AuthService.new.login(email: merchant.email, password: 'Password1!').token}"
        end
        let(:body) { { active: false } }
        run_test!
      end

      response "404", "endpoint not found" do
        schema "$ref" => "#/components/schemas/Error"

        let(:merchant) { create(:merchant) }
        let(:id) { SecureRandom.uuid }
        let(:Authorization) do
          "Bearer #{AuthService.new.login(email: merchant.email, password: 'Password1!').token}"
        end
        let(:body) { { active: false } }
        run_test!
      end

      response "401", "unauthorized" do
        schema "$ref" => "#/components/schemas/Error"
        let(:id) { SecureRandom.uuid }
        let(:Authorization) { "Bearer bad_token" }
        let(:body) { {} }
        run_test!
      end
    end

    delete "Remove a webhook endpoint" do
      tags "Webhooks"
      produces "application/json"
      parameter name: :Authorization, in: :header, schema: { type: :string }, required: true

      response "200", "endpoint removed" do
        schema type: :object, properties: { message: { type: :string } }

        let(:merchant) { create(:merchant) }
        let(:endpoint) { create(:webhook_endpoint, merchant: merchant) }
        let(:id) { endpoint.id }
        let(:Authorization) do
          "Bearer #{AuthService.new.login(email: merchant.email, password: 'Password1!').token}"
        end
        run_test!
      end

      response "404", "endpoint not found" do
        schema "$ref" => "#/components/schemas/Error"

        let(:merchant) { create(:merchant) }
        let(:id) { SecureRandom.uuid }
        let(:Authorization) do
          "Bearer #{AuthService.new.login(email: merchant.email, password: 'Password1!').token}"
        end
        run_test!
      end

      response "401", "unauthorized" do
        schema "$ref" => "#/components/schemas/Error"
        let(:id) { SecureRandom.uuid }
        let(:Authorization) { "Bearer bad_token" }
        run_test!
      end
    end
  end
end
