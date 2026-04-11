require "swagger_helper"

RSpec.describe "Charges", type: :request do
  let(:merchant)    { create(:merchant, environment: "sandbox", enabled_payment_methods: %w[card mada apple_pay]) }
  let(:api_key_rec) { create(:api_key, merchant: merchant, environment: "sandbox") }
  let(:Authorization) { "Bearer sk_test_#{SecureRandom.alphanumeric(32).downcase}" }

  before do
    allow(ApiKeyService).to receive(:authenticate).and_return(api_key_rec)
    allow(api_key_rec).to receive(:merchant).and_return(merchant)
  end

  path "/v1/charges" do
    post "Create a charge" do
      tags "Charges"
      consumes "application/json"
      produces "application/json"
      parameter name: :Authorization, in: :header, schema: { type: :string }, required: true
      parameter name: "Idempotency-Key", in: :header, schema: { type: :string, format: :uuid },
                required: true,
                description: "Unique key per charge attempt. Duplicate keys replay the original response."
      parameter name: :body, in: :body, required: true, schema: {
        "$ref" => "#/components/schemas/CreateChargeRequest"
      }

      response "201", "charge created" do
        schema "$ref" => "#/components/schemas/Charge"

        let(:"Idempotency-Key") { SecureRandom.uuid }
        let(:body) { { amount: 1000, currency: "SAR", payment_method: "card", token: "tok_visa" } }

        before do
          charge = create(:charge, :captured, merchant: merchant)
          double = instance_double(ChargeService)
          allow(double).to receive(:call).and_return(ChargeService::Result.new(charge: charge, replayed: false))
          allow(ChargeService).to receive(:new).and_return(double)
        end

        run_test!
      end

      response "200", "idempotency replay — original response returned" do
        schema "$ref" => "#/components/schemas/Charge"

        let(:"Idempotency-Key") { SecureRandom.uuid }
        let(:body) { { amount: 1000, currency: "SAR", payment_method: "card", token: "tok_visa" } }

        before do
          charge = create(:charge, :captured, merchant: merchant)
          double = instance_double(ChargeService)
          allow(double).to receive(:call).and_return(ChargeService::Result.new(charge: charge, replayed: true))
          allow(ChargeService).to receive(:new).and_return(double)
        end

        run_test!
      end

      response "401", "missing or invalid API key" do
        schema "$ref" => "#/components/schemas/Error"

        before { allow(ApiKeyService).to receive(:authenticate).and_return(nil) }
        let(:"Idempotency-Key") { SecureRandom.uuid }
        let(:body) { { amount: 1000, currency: "SAR", payment_method: "card", token: "tok_visa" } }
        run_test!
      end

      response "403", "live mode is not enabled" do
        schema "$ref" => "#/components/schemas/Error"

        let(:"Idempotency-Key") { SecureRandom.uuid }
        let(:body) { { amount: 1000, currency: "SAR", payment_method: "card", token: "tok_visa" } }

        before do
          double = instance_double(ChargeService)
          allow(double).to receive(:call).and_raise(
            PaygateError.new(message: "Live payment processing is not enabled",
                             code: "live_mode_disabled",
                             status: :forbidden)
          )
          allow(ChargeService).to receive(:new).and_return(double)
        end

        run_test!
      end

      response "422", "missing Idempotency-Key header" do
        schema "$ref" => "#/components/schemas/Error"

        let(:"Idempotency-Key") { nil }
        let(:body) { { amount: 1000, currency: "SAR", payment_method: "card", token: "tok_visa" } }

        before do
          double = instance_double(ChargeService)
          allow(double).to receive(:call).and_raise(
            IdempotencyService::MissingKeyError.new(message: "Idempotency-Key header is required",
                                                    code: "missing_idempotency_key")
          )
          allow(ChargeService).to receive(:new).and_return(double)
        end

        run_test!
      end
    end

    get "List charges" do
      tags "Charges"
      produces "application/json"
      parameter name: :Authorization, in: :header, schema: { type: :string }, required: true
      parameter name: :status, in: :query, schema: {
        type: :string,
        enum: %w[pending authorized captured failed voided refunded]
      }, required: false
      parameter name: :payment_method, in: :query, schema: {
        type: :string, enum: %w[card mada apple_pay]
      }, required: false
      parameter name: :from, in: :query, schema: { type: :string, format: "date-time" }, required: false
      parameter name: :to, in: :query, schema: { type: :string, format: "date-time" }, required: false

      response "200", "list of charges" do
        schema type: :array, items: { "$ref" => "#/components/schemas/Charge" }

        before { create_list(:charge, 3, :captured, merchant: merchant) }
        run_test!
      end

      response "401", "unauthorized" do
        schema "$ref" => "#/components/schemas/Error"

        before { allow(ApiKeyService).to receive(:authenticate).and_return(nil) }
        run_test!
      end
    end
  end

  path "/v1/charges/{id}" do
    parameter name: :id, in: :path, type: :string, required: true

    get "Retrieve a charge" do
      tags "Charges"
      produces "application/json"
      parameter name: :Authorization, in: :header, schema: { type: :string }, required: true

      response "200", "charge found" do
        schema "$ref" => "#/components/schemas/Charge"

        let(:charge) { create(:charge, :captured, merchant: merchant) }
        let(:id) { charge.id }
        run_test!
      end

      response "404", "charge not found or belongs to another merchant" do
        schema "$ref" => "#/components/schemas/Error"
        let(:id) { SecureRandom.uuid }
        run_test!
      end

      response "401", "unauthorized" do
        schema "$ref" => "#/components/schemas/Error"

        before { allow(ApiKeyService).to receive(:authenticate).and_return(nil) }
        let(:id) { SecureRandom.uuid }
        run_test!
      end
    end
  end

  path "/v1/charges/{id}/void" do
    parameter name: :id, in: :path, type: :string, required: true

    post "Void an authorized charge" do
      tags "Charges"
      produces "application/json"
      parameter name: :Authorization, in: :header, schema: { type: :string }, required: true

      response "200", "charge voided" do
        schema "$ref" => "#/components/schemas/Charge"

        let(:charge) { create(:charge, :authorized, merchant: merchant) }
        let(:id) { charge.id }

        before do
          voided_charge = create(:charge, :voided, merchant: merchant)
          double = instance_double(VoidService)
          allow(double).to receive(:call).and_return(VoidService::Result.new(charge: voided_charge))
          allow(VoidService).to receive(:new).and_return(double)
        end

        run_test!
      end

      response "422", "charge status prevents void" do
        schema "$ref" => "#/components/schemas/Error"

        let(:charge) { create(:charge, :captured, merchant: merchant) }
        let(:id) { charge.id }

        before do
          double = instance_double(VoidService)
          allow(double).to receive(:call).and_raise(
            PaygateError.new(message: "Only authorized charges can be voided",
                             code: "invalid_charge_status",
                             status: :unprocessable_content)
          )
          allow(VoidService).to receive(:new).and_return(double)
        end

        run_test!
      end

      response "404", "charge not found" do
        schema "$ref" => "#/components/schemas/Error"
        let(:id) { SecureRandom.uuid }
        run_test!
      end

      response "401", "unauthorized" do
        schema "$ref" => "#/components/schemas/Error"

        before { allow(ApiKeyService).to receive(:authenticate).and_return(nil) }
        let(:id) { SecureRandom.uuid }
        run_test!
      end
    end
  end
end
