require "swagger_helper"

RSpec.describe "Refunds", type: :request do
  let(:merchant)    { create(:merchant, environment: "sandbox", enabled_payment_methods: %w[card mada apple_pay]) }
  let(:api_key_rec) { create(:api_key, merchant: merchant, environment: "sandbox") }
  let(:Authorization) { "Bearer sk_test_#{SecureRandom.alphanumeric(32).downcase}" }
  let(:charge) { create(:charge, :captured, merchant: merchant, amount: 1000) }

  before do
    allow(ApiKeyService).to receive(:authenticate).and_return(api_key_rec)
    allow(api_key_rec).to receive(:merchant).and_return(merchant)
  end

  path "/v1/charges/{charge_id}/refunds" do
    parameter name: :charge_id, in: :path, type: :string, required: true

    post "Create a refund" do
      tags "Refunds"
      consumes "application/json"
      produces "application/json"
      parameter name: :Authorization, in: :header, schema: { type: :string }, required: true
      parameter name: :body, in: :body, required: true, schema: {
        "$ref" => "#/components/schemas/CreateRefundRequest"
      }

      response "201", "refund created" do
        schema "$ref" => "#/components/schemas/Refund"

        let(:charge_id) { charge.id }
        let(:refund) { create(:refund, merchant: merchant, charge_id: charge.id, amount: 500) }
        let(:body) { { amount: 500, reason: "requested_by_customer" } }

        before do
          allow(RefundService).to receive(:new).and_return(
            instance_double(RefundService, call: RefundService::Result.new(refund: refund))
          )
        end

        run_test!
      end

      response "422", "amount exceeds refundable balance" do
        schema "$ref" => "#/components/schemas/Error"

        let(:charge_id) { charge.id }
        let(:body) { { amount: 99_999 } }

        before do
          double = instance_double(RefundService)
          allow(double).to receive(:call).and_raise(
            PaygateError.new(message: "Refund amount exceeds the remaining refundable amount",
                             code: "amount_exceeds_charge",
                             status: :unprocessable_content)
          )
          allow(RefundService).to receive(:new).and_return(double)
        end

        run_test!
      end

      response "404", "charge not found" do
        schema "$ref" => "#/components/schemas/Error"
        let(:charge_id) { SecureRandom.uuid }
        let(:body) { { amount: 500 } }

        before do
          double = instance_double(RefundService)
          allow(double).to receive(:call).and_raise(ActiveRecord::RecordNotFound)
          allow(RefundService).to receive(:new).and_return(double)
        end

        run_test!
      end

      response "401", "unauthorized" do
        schema "$ref" => "#/components/schemas/Error"

        before { allow(ApiKeyService).to receive(:authenticate).and_return(nil) }
        let(:charge_id) { SecureRandom.uuid }
        let(:body) { { amount: 500 } }
        run_test!
      end
    end

    get "List refunds for a charge" do
      tags "Refunds"
      produces "application/json"
      parameter name: :Authorization, in: :header, schema: { type: :string }, required: true

      response "200", "list of refunds" do
        schema type: :array, items: { "$ref" => "#/components/schemas/Refund" }

        let(:charge_id) { charge.id }
        before { create_list(:refund, 2, merchant: merchant, charge_id: charge.id) }
        run_test!
      end

      response "404", "charge not found or belongs to another merchant" do
        schema "$ref" => "#/components/schemas/Error"
        let(:charge_id) { SecureRandom.uuid }
        run_test!
      end

      response "401", "unauthorized" do
        schema "$ref" => "#/components/schemas/Error"

        before { allow(ApiKeyService).to receive(:authenticate).and_return(nil) }
        let(:charge_id) { SecureRandom.uuid }
        run_test!
      end
    end
  end

  path "/v1/refunds/{id}" do
    parameter name: :id, in: :path, type: :string, required: true

    get "Retrieve a refund" do
      tags "Refunds"
      produces "application/json"
      parameter name: :Authorization, in: :header, schema: { type: :string }, required: true

      response "200", "refund found" do
        schema "$ref" => "#/components/schemas/Refund"

        let(:refund) { create(:refund, merchant: merchant, charge_id: charge.id) }
        let(:id) { refund.id }
        run_test!
      end

      response "404", "refund not found or belongs to another merchant" do
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
