require "rails_helper"

RSpec.describe "Entity IDs (/v1/me/entity_ids)" do
  let!(:merchant) { create(:merchant) }
  let(:token) { AuthService.new.login(email: merchant.email, password: "Password1!").token }
  let(:headers) { auth_headers(token) }

  describe "GET /v1/me/entity_ids" do
    before do
      create(:entity_id, merchant: merchant, brand: "card")
      create(:entity_id, merchant: merchant, brand: "mada")
    end

    it "returns all entity IDs for the merchant" do
      get "/v1/me/entity_ids", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response.length).to eq(2)
      expect(json_response.map { _1[:brand] }).to contain_exactly("card", "mada")
    end

    it "does not return entity IDs belonging to another merchant" do
      create(:entity_id)
      get "/v1/me/entity_ids", headers: headers, as: :json

      expect(json_response.length).to eq(2)
    end

    it "returns 401 without a token" do
      get "/v1/me/entity_ids", as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /v1/me/entity_ids" do
    let(:valid_params) { { brand: "card", environment: "sandbox", entity_id: "8ac7a4ca12345678" } }

    it "creates an entity ID" do
      post "/v1/me/entity_ids", params: valid_params, headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response[:brand]).to eq("card")
      expect(json_response[:entity_id]).to eq("8ac7a4ca12345678")
    end

    it "returns 422 for an invalid brand" do
      post "/v1/me/entity_ids",
           params: { brand: "paypal", environment: "sandbox", entity_id: "abc123" },
           headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 422 for a duplicate brand/environment combination" do
      create(:entity_id, merchant: merchant, brand: "card", environment: "sandbox")
      post "/v1/me/entity_ids", params: valid_params, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 401 without a token" do
      post "/v1/me/entity_ids", params: valid_params, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /v1/me/entity_ids/:id" do
    let!(:entity_id) { create(:entity_id, merchant: merchant) }

    it "removes the entity ID" do
      delete "/v1/me/entity_ids/#{entity_id.id}", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response[:message]).to eq("Entity ID removed")
      expect(EntityId.find_by(id: entity_id.id)).to be_nil
    end

    it "returns 404 for another merchant's entity ID" do
      other_entity_id = create(:entity_id)
      delete "/v1/me/entity_ids/#{other_entity_id.id}", headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 without a token" do
      delete "/v1/me/entity_ids/#{entity_id.id}", as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
