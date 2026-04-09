require "rails_helper"

RSpec.describe "Auth Sessions" do
  let!(:merchant) { create(:merchant, email: "test@example.com", password: "Password1!") }

  describe "POST /v1/auth/login" do
    it "returns 200 with a JWT token on valid credentials" do
      post "/v1/auth/login", params: { email: "test@example.com", password: "Password1!" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response[:token]).to be_present
      expect(json_response[:merchant][:id]).to eq(merchant.id)
    end

    it "returns 401 on wrong password" do
      post "/v1/auth/login", params: { email: "test@example.com", password: "wrong" }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(json_response[:error][:code]).to eq("invalid_credentials")
    end

    it "returns 401 on unknown email" do
      post "/v1/auth/login", params: { email: "nobody@example.com", password: "Password1!" }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /v1/auth/logout" do
    let(:token) { AuthService.new.login(email: merchant.email, password: "Password1!").token }

    it "returns 200 and revokes the token" do
      delete "/v1/auth/logout", headers: auth_headers(token), as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response[:message]).to eq("Logged out successfully")
    end

    it "returns 401 if the token is used again after logout" do
      delete "/v1/auth/logout", headers: auth_headers(token), as: :json
      expect(response).to have_http_status(:ok)

      delete "/v1/auth/logout", headers: auth_headers(token), as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 without an Authorization header" do
      delete "/v1/auth/logout", as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
