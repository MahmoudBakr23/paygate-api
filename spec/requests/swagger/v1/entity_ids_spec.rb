require "swagger_helper"

RSpec.describe "Entity IDs", type: :request do
  path "/v1/me/entity_ids" do
    get "List entity IDs" do
      tags "Entity IDs"
      produces "application/json"
      parameter name: :Authorization, in: :header, schema: { type: :string }, required: true

      response "200", "list of entity IDs" do
        schema type: :array, items: { "$ref" => "#/components/schemas/EntityId" }

        let(:merchant) { create(:merchant) }
        let(:Authorization) do
          "Bearer #{AuthService.new.login(email: merchant.email, password: 'Password1!').token}"
        end
        before do
          create(:entity_id, merchant: merchant, brand: "card")
          create(:entity_id, merchant: merchant, brand: "mada")
        end
        run_test!
      end

      response "401", "unauthorized" do
        schema "$ref" => "#/components/schemas/Error"
        let(:Authorization) { "Bearer bad_token" }
        run_test!
      end
    end

    post "Create an entity ID" do
      tags "Entity IDs"
      consumes "application/json"
      produces "application/json"
      parameter name: :Authorization, in: :header, schema: { type: :string }, required: true
      parameter name: :body, in: :body, required: true, schema: {
        "$ref" => "#/components/schemas/CreateEntityIdRequest"
      }

      response "201", "entity ID created" do
        schema "$ref" => "#/components/schemas/EntityId"

        let(:merchant) { create(:merchant) }
        let(:Authorization) do
          "Bearer #{AuthService.new.login(email: merchant.email, password: 'Password1!').token}"
        end
        let(:body) { { brand: "card", environment: "sandbox", entity_id: "8ac7a4ca12345678" } }
        run_test!
      end

      response "422", "invalid brand or duplicate entry" do
        schema "$ref" => "#/components/schemas/Error"

        let(:merchant) { create(:merchant) }
        let(:Authorization) do
          "Bearer #{AuthService.new.login(email: merchant.email, password: 'Password1!').token}"
        end
        let(:body) { { brand: "paypal", environment: "sandbox", entity_id: "abc" } }
        run_test!
      end

      response "401", "unauthorized" do
        schema "$ref" => "#/components/schemas/Error"
        let(:Authorization) { "Bearer bad_token" }
        let(:body) { { brand: "card", environment: "sandbox", entity_id: "abc" } }
        run_test!
      end
    end
  end

  path "/v1/me/entity_ids/{id}" do
    parameter name: :id, in: :path, type: :string, required: true

    delete "Remove an entity ID" do
      tags "Entity IDs"
      produces "application/json"
      parameter name: :Authorization, in: :header, schema: { type: :string }, required: true

      response "200", "entity ID removed" do
        schema type: :object, properties: { message: { type: :string } }

        let(:merchant) { create(:merchant) }
        let(:entity_id_record) { create(:entity_id, merchant: merchant) }
        let(:id) { entity_id_record.id }
        let(:Authorization) do
          "Bearer #{AuthService.new.login(email: merchant.email, password: 'Password1!').token}"
        end
        run_test!
      end

      response "404", "entity ID not found" do
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
