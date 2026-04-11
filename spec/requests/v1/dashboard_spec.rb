require "rails_helper"

RSpec.describe "Dashboard Stats (/v1/me/dashboard)" do
  let!(:merchant) { create(:merchant) }
  let(:token) { AuthService.new.login(email: merchant.email, password: "Password1!").token }
  let(:headers) { auth_headers(token) }

  describe "GET /v1/me/dashboard" do
    before do
      create(:charge, merchant: merchant, status: "captured", amount: 10_000, payment_method: "card")
      create(:charge, merchant: merchant, status: "captured", amount: 5_000, payment_method: "mada")
      create(:charge, merchant: merchant, status: "failed", amount: 3_000, payment_method: "card")
      create(:charge, merchant: merchant, status: "refunded", amount: 10_000, payment_method: "card")
    end

    it "returns aggregated stats" do
      get "/v1/me/dashboard", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response[:total_charges]).to eq(4)
      expect(json_response[:captured_count]).to eq(2)
      expect(json_response[:failed_count]).to eq(1)
      expect(json_response[:refunded_count]).to eq(1)
      expect(json_response[:total_volume]).to eq(15_000)
      expect(json_response[:currency]).to eq("SAR")
    end

    it "calculates success_rate correctly" do
      get "/v1/me/dashboard", headers: headers, as: :json

      expect(json_response[:success_rate]).to eq(50.0)
    end

    it "returns volume_by_method breakdown" do
      get "/v1/me/dashboard", headers: headers, as: :json

      expect(json_response[:volume_by_method][:card]).to eq(10_000)
      expect(json_response[:volume_by_method][:mada]).to eq(5_000)
    end

    it "returns zeros when merchant has no charges" do
      new_merchant = create(:merchant)
      new_token = AuthService.new.login(email: new_merchant.email, password: "Password1!").token

      get "/v1/me/dashboard", headers: auth_headers(new_token), as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response[:total_charges]).to eq(0)
      expect(json_response[:success_rate]).to eq(0.0)
      expect(json_response[:total_volume]).to eq(0)
    end

    it "does not include charges from other merchants" do
      create(:charge, status: "captured", amount: 99_999, payment_method: "card")
      get "/v1/me/dashboard", headers: headers, as: :json

      expect(json_response[:total_charges]).to eq(4)
    end

    it "returns 401 without a token" do
      get "/v1/me/dashboard", as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
