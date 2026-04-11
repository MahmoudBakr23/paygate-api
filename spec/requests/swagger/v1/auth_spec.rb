require "swagger_helper"

RSpec.describe "Auth", type: :request do
  path "/v1/auth/register" do
    post "Register a new merchant" do
      tags "Authentication"
      consumes "application/json"
      produces "application/json"
      security []

      parameter name: :body, in: :body, required: true, schema: {
        "$ref" => "#/components/schemas/RegisterRequest"
      }

      response "201", "merchant created with sandbox key pair" do
        schema type: :object,
          properties: {
            token: { type: :string, description: "JWT session token" },
            merchant: { "$ref" => "#/components/schemas/Merchant" },
            api_keys: {
              type: :object,
              properties: {
                public_key: { type: :string, example: "pk_test_abc..." },
                secret_key: { type: :string, description: "Shown once — store immediately", example: "sk_test_xyz..." }
              }
            }
          }

        let(:body) { { name: "Acme Corp", email: "acme@example.com", password: "Password1!" } }
        run_test!
      end

      response "422", "validation error" do
        schema "$ref" => "#/components/schemas/Error"
        let(:body) { { name: "Acme Corp", email: "not-an-email", password: "Password1!" } }
        run_test!
      end
    end
  end

  path "/v1/auth/login" do
    post "Login and obtain a JWT" do
      tags "Authentication"
      consumes "application/json"
      produces "application/json"
      security []

      parameter name: :body, in: :body, required: true, schema: {
        "$ref" => "#/components/schemas/LoginRequest"
      }

      response "200", "login successful" do
        schema type: :object,
          properties: {
            token: { type: :string },
            merchant: { "$ref" => "#/components/schemas/Merchant" }
          }

        before { create(:merchant, email: "acme@example.com", password: "Password1!") }
        let(:body) { { email: "acme@example.com", password: "Password1!" } }
        run_test!
      end

      response "401", "invalid credentials" do
        schema "$ref" => "#/components/schemas/Error"
        let(:body) { { email: "nobody@example.com", password: "wrong" } }
        run_test!
      end
    end
  end

  path "/v1/auth/logout" do
    delete "Revoke the current session" do
      tags "Authentication"
      produces "application/json"

      parameter name: :Authorization, in: :header, schema: { type: :string }, required: true

      response "200", "logged out successfully" do
        schema type: :object, properties: { message: { type: :string } }

        let(:merchant) { create(:merchant) }
        let(:Authorization) do
          "Bearer #{AuthService.new.login(email: merchant.email, password: 'Password1!').token}"
        end
        run_test!
      end

      response "401", "missing or revoked token" do
        schema "$ref" => "#/components/schemas/Error"
        let(:Authorization) { "Bearer invalid_token" }
        run_test!
      end
    end
  end
end
