require "rails_helper"

RSpec.describe "V1::Refunds", type: :request do
  let(:merchant)    { create(:merchant, environment: "sandbox", enabled_payment_methods: %w[card mada apple_pay]) }
  let(:api_key_rec) { create(:api_key, merchant: merchant, environment: "sandbox") }
  let(:charge)      { create(:charge, :captured, merchant: merchant, amount: 1000) }
  let(:headers) do
    {
      "Authorization" => "Bearer sk_test_#{SecureRandom.alphanumeric(32).downcase}",
      "Content-Type"  => "application/json"
    }
  end

  before do
    allow(ApiKeyService).to receive(:authenticate).and_return(api_key_rec)
    allow(api_key_rec).to receive(:merchant).and_return(merchant)
  end

  describe "POST /v1/charges/:charge_id/refunds" do
    let(:params) { { amount: 500, reason: "requested_by_customer" }.to_json }
    let(:refund_service_double) { instance_double(RefundService) }
    let(:refund) { create(:refund, merchant: merchant, charge_id: charge.id, amount: 500) }

    before do
      allow(RefundService).to receive(:new).and_return(refund_service_double)
      allow(refund_service_double).to receive(:call).and_return(RefundService::Result.new(refund: refund))
    end

    it "returns 201 with refund JSON" do
      post "/v1/charges/#{charge.id}/refunds", params: params, headers: headers

      expect(response).to have_http_status(:created)
      body = json_response
      expect(body[:id]).to eq(refund.id)
      expect(body[:amount]).to eq(500)
      expect(body[:status]).to eq("succeeded")
    end

    it "returns 401 without Authorization header" do
      post "/v1/charges/#{charge.id}/refunds", params: params,
           headers: headers.except("Authorization")

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 404 when charge not found" do
      allow(refund_service_double).to receive(:call).and_raise(
        ActiveRecord::RecordNotFound
      )

      post "/v1/charges/#{SecureRandom.uuid}/refunds", params: params, headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "returns 422 when charge status is invalid" do
      allow(refund_service_double).to receive(:call).and_raise(
        PaygateError.new(
          message: "Charge cannot be refunded in status 'authorized'",
          code: "invalid_charge_status",
          status: :unprocessable_content
        )
      )

      post "/v1/charges/#{charge.id}/refunds", params: params, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response[:error][:code]).to eq("invalid_charge_status")
    end

    it "returns 422 when amount exceeds charge" do
      allow(refund_service_double).to receive(:call).and_raise(
        PaygateError.new(
          message: "Refund amount exceeds the remaining refundable amount",
          code: "amount_exceeds_charge",
          status: :unprocessable_content
        )
      )

      post "/v1/charges/#{charge.id}/refunds",
           params: { amount: 9999 }.to_json,
           headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response[:error][:code]).to eq("amount_exceeds_charge")
    end
  end

  describe "GET /v1/charges/:charge_id/refunds" do
    before do
      create_list(:refund, 3, merchant: merchant, charge_id: charge.id)
      create(:refund, merchant: merchant)  # other charge's refund
    end

    it "returns refunds for the charge" do
      get "/v1/charges/#{charge.id}/refunds", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response.length).to eq(3)
      expect(json_response.map { |r| r[:charge_id] }.uniq).to eq([charge.id])
    end

    it "returns 404 for a charge not belonging to merchant" do
      other_charge = create(:charge, :captured)

      get "/v1/charges/#{other_charge.id}/refunds", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /v1/refunds/:id" do
    let(:refund) { create(:refund, merchant: merchant, charge_id: charge.id) }

    it "returns the refund" do
      get "/v1/refunds/#{refund.id}", headers: headers

      expect(response).to have_http_status(:ok)
      body = json_response
      expect(body[:id]).to eq(refund.id)
      expect(body[:charge_id]).to eq(charge.id)
    end

    it "returns 404 for a refund belonging to another merchant" do
      other_refund = create(:refund)

      get "/v1/refunds/#{other_refund.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
