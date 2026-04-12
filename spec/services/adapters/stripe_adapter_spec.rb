require "rails_helper"

RSpec.describe Adapters::StripeAdapter do
  let(:adapter) { described_class.new(environment: "sandbox") }
  let(:api_key) { ENV.fetch("STRIPE_SANDBOX_SECRET_KEY", "sk_test_fake") }

  before do
    stub_const("ENV", ENV.to_h.merge("STRIPE_SANDBOX_SECRET_KEY" => api_key))
  end

  # Stubs the PaymentMethod creation step that happens when a tok_... is passed.
  def stub_payment_method_create(pm_id: "pm_test_visa")
    stub_request(:post, "https://api.stripe.com/v1/payment_methods")
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: { id: pm_id, type: "card" }.to_json
      )
  end

  describe "#charge" do
    context "when token is a legacy tok_... token" do
      before { stub_payment_method_create }

      context "when payment succeeds" do
        before do
          stub_request(:post, "https://api.stripe.com/v1/payment_intents")
            .to_return(
              status: 200,
              headers: { "Content-Type" => "application/json" },
              body: {
                id: "pi_test_succeeded",
                status: "succeeded",
                amount: 1000,
                currency: "sar"
              }.to_json
            )
        end

        it "returns a captured ChargeResult" do
          result = adapter.charge(amount: 1000, currency: "SAR", token: "tok_visa")

          expect(result.provider_charge_id).to eq("pi_test_succeeded")
          expect(result.status).to eq("captured")
          expect(result.failure_code).to be_nil
          expect(result.failure_message).to be_nil
        end

        it "converts the tok_... to a pm_... before creating the PaymentIntent" do
          adapter.charge(amount: 1000, currency: "SAR", token: "tok_visa")

          expect(WebMock).to have_requested(:post, "https://api.stripe.com/v1/payment_methods")
            .with(body: hash_including("card" => hash_including("token" => "tok_visa")))
        end
      end

      context "when requires_capture (authorize only)" do
        before do
          stub_request(:post, "https://api.stripe.com/v1/payment_intents")
            .to_return(
              status: 200,
              headers: { "Content-Type" => "application/json" },
              body: { id: "pi_test_auth", status: "requires_capture" }.to_json
            )
        end

        it "returns an authorized ChargeResult" do
          result = adapter.charge(amount: 1000, currency: "SAR", token: "tok_visa")

          expect(result.status).to eq("authorized")
        end
      end

      context "when card requires 3D Secure authentication" do
        before do
          stub_request(:post, "https://api.stripe.com/v1/payment_intents")
            .to_return(
              status: 200,
              headers: { "Content-Type" => "application/json" },
              body: { id: "pi_test_3ds", status: "requires_action" }.to_json
            )
        end

        it "returns a failed ChargeResult with requires_action code" do
          result = adapter.charge(amount: 1000, currency: "SAR", token: "tok_visa")

          expect(result.status).to eq("failed")
          expect(result.failure_code).to eq("requires_action")
          expect(result.failure_message).to include("3D Secure")
        end
      end

      context "when card is declined" do
        before do
          stub_request(:post, "https://api.stripe.com/v1/payment_intents")
            .to_return(
              status: 402,
              headers: { "Content-Type" => "application/json" },
              body: {
                error: {
                  type: "card_error",
                  code: "card_declined",
                  message: "Your card was declined.",
                  payment_intent: { id: "pi_test_declined" }
                }
              }.to_json
            )
        end

        it "returns a failed ChargeResult without raising" do
          result = adapter.charge(amount: 1000, currency: "SAR", token: "tok_card_declined")

          expect(result.status).to eq("failed")
          expect(result.failure_code).to eq("card_declined")
          expect(result.failure_message).to include("declined")
        end
      end

      context "when Stripe is unreachable" do
        before do
          stub_request(:post, "https://api.stripe.com/v1/payment_intents")
            .to_timeout
        end

        it "raises PaygateError with provider_error code" do
          expect {
            adapter.charge(amount: 1000, currency: "SAR", token: "tok_visa")
          }.to raise_error(PaygateError) { |e|
            expect(e.code).to eq("provider_error")
            expect(e.status).to eq(:bad_gateway)
          }
        end
      end
    end

    context "when token is already a pm_... PaymentMethod ID" do
      it "skips PaymentMethod creation and uses the pm_... directly" do
        stub_request(:post, "https://api.stripe.com/v1/payment_intents")
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: { id: "pi_test_pm", status: "succeeded" }.to_json
          )

        result = adapter.charge(amount: 1000, currency: "SAR", token: "pm_test_existing")

        expect(result.status).to eq("captured")
        expect(WebMock).not_to have_requested(:post, "https://api.stripe.com/v1/payment_methods")
      end
    end
  end

  describe "#refund" do
    context "when refund succeeds" do
      before do
        stub_request(:post, "https://api.stripe.com/v1/refunds")
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: { id: "re_test_123", status: "succeeded" }.to_json
          )
      end

      it "returns a succeeded RefundResult" do
        result = adapter.refund(provider_charge_id: "pi_test_123", amount: 500)

        expect(result.provider_refund_id).to eq("re_test_123")
        expect(result.status).to eq("succeeded")
      end
    end
  end

  describe "#void" do
    context "when void succeeds" do
      before do
        stub_request(:post, "https://api.stripe.com/v1/payment_intents/pi_test_123/cancel")
          .to_return(
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: { id: "pi_test_123", status: "canceled" }.to_json
          )
      end

      it "returns a voided VoidResult" do
        result = adapter.void(provider_charge_id: "pi_test_123")

        expect(result.status).to eq("voided")
        expect(result.failure_message).to be_nil
      end
    end
  end
end
