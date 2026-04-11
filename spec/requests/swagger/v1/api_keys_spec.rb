require "swagger_helper"

RSpec.describe "API Keys", type: :request do
  path "/v1/me/api_keys" do
    get "List active API keys" do
      tags "API Keys"
      produces "application/json"
      parameter name: :Authorization, in: :header, schema: { type: :string }, required: true

      response "200", "list of active API keys" do
        schema type: :array, items: { "$ref" => "#/components/schemas/ApiKey" }

        let(:merchant) { create(:merchant) }
        let(:Authorization) do
          "Bearer #{AuthService.new.login(email: merchant.email, password: 'Password1!').token}"
        end
        before { create_list(:api_key, 2, merchant: merchant) }
        run_test!
      end

      response "401", "unauthorized" do
        schema "$ref" => "#/components/schemas/Error"
        let(:Authorization) { "Bearer bad_token" }
        run_test!
      end
    end

    post "Generate a new API key pair" do
      tags "API Keys"
      consumes "application/json"
      produces "application/json"
      parameter name: :Authorization, in: :header, schema: { type: :string }, required: true
      parameter name: :body, in: :body, schema: { "$ref" => "#/components/schemas/CreateApiKeyRequest" }

      response "201", "key pair created — secret shown once" do
        schema "$ref" => "#/components/schemas/ApiKeyCreated"

        let(:merchant) { create(:merchant) }
        let(:Authorization) do
          "Bearer #{AuthService.new.login(email: merchant.email, password: 'Password1!').token}"
        end
        let(:body) { { environment: "sandbox" } }
        run_test!
      end

      response "422", "invalid environment" do
        schema "$ref" => "#/components/schemas/Error"

        let(:merchant) { create(:merchant) }
        let(:Authorization) do
          "Bearer #{AuthService.new.login(email: merchant.email, password: 'Password1!').token}"
        end
        let(:body) { { environment: "staging" } }
        run_test!
      end

      response "401", "unauthorized" do
        schema "$ref" => "#/components/schemas/Error"
        let(:Authorization) { "Bearer bad_token" }
        let(:body) { {} }
        run_test!
      end
    end
  end

  path "/v1/me/api_keys/{id}" do
    parameter name: :id, in: :path, type: :string, required: true

    delete "Revoke an API key" do
      tags "API Keys"
      produces "application/json"
      parameter name: :Authorization, in: :header, schema: { type: :string }, required: true

      response "200", "key revoked" do
        schema "$ref" => "#/components/schemas/ApiKey"

        let(:merchant) { create(:merchant) }
        let(:api_key) { create(:api_key, merchant: merchant) }
        let(:id) { api_key.id }
        let(:Authorization) do
          "Bearer #{AuthService.new.login(email: merchant.email, password: 'Password1!').token}"
        end
        run_test!
      end

      response "404", "key not found" do
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
