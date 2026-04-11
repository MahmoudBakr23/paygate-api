require "swagger_helper"

RSpec.describe "Merchants", type: :request do
  path "/v1/me" do
    get "Retrieve merchant profile" do
      tags "Merchant"
      produces "application/json"
      parameter name: :Authorization, in: :header, schema: { type: :string }, required: true

      response "200", "merchant profile" do
        schema "$ref" => "#/components/schemas/Merchant"

        let(:merchant) { create(:merchant) }
        let(:Authorization) do
          "Bearer #{AuthService.new.login(email: merchant.email, password: 'Password1!').token}"
        end
        run_test!
      end

      response "401", "unauthorized" do
        schema "$ref" => "#/components/schemas/Error"
        let(:Authorization) { "Bearer bad_token" }
        run_test!
      end
    end

    patch "Update merchant profile" do
      tags "Merchant"
      consumes "application/json"
      produces "application/json"
      parameter name: :Authorization, in: :header, schema: { type: :string }, required: true
      parameter name: :body, in: :body, required: true, schema: {
        "$ref" => "#/components/schemas/UpdateMerchantRequest"
      }

      response "200", "merchant updated" do
        schema "$ref" => "#/components/schemas/Merchant"

        let(:merchant) { create(:merchant) }
        let(:Authorization) do
          "Bearer #{AuthService.new.login(email: merchant.email, password: 'Password1!').token}"
        end
        let(:body) { { name: "Updated Corp", webhook_url: "https://example.com/hooks" } }
        run_test!
      end

      response "401", "unauthorized" do
        schema "$ref" => "#/components/schemas/Error"
        let(:Authorization) { "Bearer bad_token" }
        let(:body) { { name: "Updated Corp" } }
        run_test!
      end
    end
  end
end
