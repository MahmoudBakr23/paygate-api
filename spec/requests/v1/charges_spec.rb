require "rails_helper"

RSpec.describe "V1::Charges", type: :request do
  let(:merchant)    { create(:merchant, environment: "sandbox", enabled_payment_methods: %w[card mada apple_pay]) }
  let(:api_key_rec) { create(:api_key, merchant: merchant, environment: "sandbox") }
  let(:secret_key)  { "sk_test_#{SecureRandom.alphanumeric(32).downcase}" }
  let(:headers) do
    {
      "Authorization"   => "Bearer #{secret_key}",
      "Content-Type"    => "application/json",
      "Idempotency-Key" => SecureRandom.uuid
    }
  end

  let(:successful_result) do
    ChargeService::Result.new(
      charge: build_stubbed_charge(merchant: merchant),
      replayed: false
    )
  end

  let(:charge_service_double) { instance_double(ChargeService) }

  before do
    # Stub API key auth so we don't need a real bcrypt round-trip
    allow(ApiKeyService).to receive(:authenticate).and_return(api_key_rec)
    allow(api_key_rec).to receive(:merchant).and_return(merchant)
    allow(ChargeService).to receive(:new).and_return(charge_service_double)
    allow(charge_service_double).to receive(:call).and_return(successful_result)
  end

  describe "POST /v1/charges" do
    let(:params) do
      { amount: 1000, currency: "SAR", payment_method: "card", token: "tok_visa" }.to_json
    end

    it "returns 201 with charge JSON" do
      post "/v1/charges", params: params, headers: headers

      expect(response).to have_http_status(:created)
      body = json_response
      expect(body[:id]).to be_present
      expect(body[:status]).to eq("captured")
      expect(body[:amount]).to eq(1000)
    end

    it "returns 200 on idempotency replay" do
      replayed_result = ChargeService::Result.new(
        charge: build_stubbed_charge(merchant: merchant),
        replayed: true
      )
      allow(charge_service_double).to receive(:call).and_return(replayed_result)

      post "/v1/charges", params: params, headers: headers

      expect(response).to have_http_status(:ok)
    end

    it "returns 422 when Idempotency-Key header is missing" do
      allow(charge_service_double).to receive(:call).and_raise(
        IdempotencyService::MissingKeyError.new(
          message: "Idempotency-Key header is required for this request",
          code: "missing_idempotency_key"
        )
      )

      post "/v1/charges", params: params,
           headers: headers.except("Idempotency-Key")

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response[:error][:code]).to eq("missing_idempotency_key")
    end

    it "returns 401 without Authorization header" do
      post "/v1/charges", params: params,
           headers: headers.except("Authorization")

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for live mode attempts" do
      allow(charge_service_double).to receive(:call).and_raise(
        PaygateError.new(
          message: "Live payment processing is not enabled",
          code: "live_mode_disabled",
          status: :forbidden
        )
      )

      post "/v1/charges", params: params, headers: headers

      expect(response).to have_http_status(:forbidden)
      expect(json_response[:error][:code]).to eq("live_mode_disabled")
    end
  end

  describe "GET /v1/charges/:id" do
    let(:charge) { create(:charge, :captured, merchant: merchant) }

    before do
      allow(ApiKeyService).to receive(:authenticate).and_return(api_key_rec)
    end

    it "returns the charge" do
      get "/v1/charges/#{charge.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response[:id]).to eq(charge.id)
      expect(json_response[:status]).to eq("captured")
    end

    it "returns 404 for a charge belonging to another merchant" do
      other_charge = create(:charge, :captured)

      get "/v1/charges/#{other_charge.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /v1/charges" do
    before do
      create_list(:charge, 3, :captured, merchant: merchant)
      create(:charge, :failed, merchant: merchant)
    end

    it "returns all charges for the merchant" do
      get "/v1/charges", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response.length).to eq(4)
    end

    it "filters by status" do
      get "/v1/charges", params: { status: "failed" }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response.length).to eq(1)
      expect(json_response.first[:status]).to eq("failed")
    end

    it "does not return charges from other merchants" do
      create(:charge, :captured)

      get "/v1/charges", headers: headers

      expect(json_response.length).to eq(4)
    end
  end

  private

  def build_stubbed_charge(merchant:)
    build_stubbed(
      :charge,
      :captured,
      merchant: merchant,
      provider_charge_id: "pi_test_stub"
    )
  end
end
