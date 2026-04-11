require "swagger_helper"

RSpec.describe "Dashboard", type: :request do
  path "/v1/me/dashboard" do
    get "Retrieve aggregated dashboard stats" do
      tags "Dashboard"
      produces "application/json"
      parameter name: :Authorization, in: :header, schema: { type: :string }, required: true

      response "200", "dashboard statistics" do
        schema "$ref" => "#/components/schemas/DashboardStats"

        let(:merchant) { create(:merchant) }
        let(:Authorization) do
          "Bearer #{AuthService.new.login(email: merchant.email, password: 'Password1!').token}"
        end
        before do
          create(:charge, merchant: merchant, status: "captured", amount: 10_000, payment_method: "card")
          create(:charge, merchant: merchant, status: "captured", amount: 5_000, payment_method: "mada")
          create(:charge, merchant: merchant, status: "failed", amount: 3_000, payment_method: "card")
        end
        run_test!
      end

      response "401", "unauthorized" do
        schema "$ref" => "#/components/schemas/Error"
        let(:Authorization) { "Bearer bad_token" }
        run_test!
      end
    end
  end
end
