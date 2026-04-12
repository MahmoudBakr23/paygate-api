require "rails_helper"

RSpec.describe Adapters::CheckoutAdapter do
  let(:adapter) { described_class.new(environment: "sandbox") }

  before do
    stub_const("ENV", ENV.to_h.merge("CHECKOUT_SANDBOX_SECRET_KEY" => "sk_sbox_fake"))
  end

  describe "#charge" do
    context "with tok_mada (sandbox simulation token)" do
      it "returns a captured ChargeResult without calling Checkout.com" do
        result = adapter.charge(amount: 1000, currency: "SAR", token: "tok_mada")

        expect(result.status).to eq("captured")
        expect(result.provider_charge_id).to start_with("pay_mada_sandbox_")
        expect(result.failure_code).to be_nil
        expect(WebMock).not_to have_requested(:post, "#{described_class::BASE_URL_SANDBOX}/payments")
      end
    end

    context "with a real Checkout.com token" do
      context "when payment is captured" do
        before do
          stub_request(:post, "#{described_class::BASE_URL_SANDBOX}/payments")
            .to_return(
              status: 201,
              headers: { "Content-Type" => "application/json" },
              body: {
                id: "pay_checkout_123",
                status: "Captured",
                amount: 1000,
                currency: "SAR"
              }.to_json
            )
        end

        it "returns a captured ChargeResult" do
          result = adapter.charge(amount: 1000, currency: "SAR", token: "cko_tok_real")

          expect(result.provider_charge_id).to eq("pay_checkout_123")
          expect(result.status).to eq("captured")
          expect(result.failure_code).to be_nil
        end
      end

      context "when payment is authorized" do
        before do
          stub_request(:post, "#{described_class::BASE_URL_SANDBOX}/payments")
            .to_return(
              status: 201,
              headers: { "Content-Type" => "application/json" },
              body: { id: "pay_checkout_auth", status: "Authorized" }.to_json
            )
        end

        it "returns an authorized ChargeResult" do
          result = adapter.charge(amount: 1000, currency: "SAR", token: "cko_tok_real")

          expect(result.status).to eq("authorized")
        end
      end

      context "when payment is declined" do
        before do
          stub_request(:post, "#{described_class::BASE_URL_SANDBOX}/payments")
            .to_return(
              status: 422,
              headers: { "Content-Type" => "application/json" },
              body: {
                error_codes: ["card_declined"],
                message: "Payment was declined"
              }.to_json
            )
        end

        it "returns a failed ChargeResult without raising" do
          result = adapter.charge(amount: 1000, currency: "SAR", token: "tok_mada_declined")

          expect(result.status).to eq("failed")
          expect(result.failure_code).to eq("card_declined")
        end
      end

      context "when Checkout.com is unreachable" do
        before do
          stub_request(:post, "#{described_class::BASE_URL_SANDBOX}/payments")
            .to_raise(Errno::ECONNREFUSED)
        end

        it "raises PaygateError with provider_error code" do
          expect {
            adapter.charge(amount: 1000, currency: "SAR", token: "cko_tok_real")
          }.to raise_error(PaygateError) { |e|
            expect(e.code).to eq("provider_error")
            expect(e.status).to eq(:bad_gateway)
          }
        end
      end
    end
  end

  describe "#refund" do
    context "when refund is accepted" do
      before do
        stub_request(:post, "#{described_class::BASE_URL_SANDBOX}/payments/pay_123/refunds")
          .to_return(
            status: 202,
            headers: { "Content-Type" => "application/json" },
            body: { action_id: "act_refund_123" }.to_json
          )
      end

      it "returns a succeeded RefundResult" do
        result = adapter.refund(provider_charge_id: "pay_123", amount: 500)

        expect(result.provider_refund_id).to eq("act_refund_123")
        expect(result.status).to eq("succeeded")
      end
    end
  end

  describe "#void" do
    context "when void is accepted" do
      before do
        stub_request(:post, "#{described_class::BASE_URL_SANDBOX}/payments/pay_123/voids")
          .to_return(
            status: 202,
            headers: { "Content-Type" => "application/json" },
            body: { action_id: "act_void_123" }.to_json
          )
      end

      it "returns a voided VoidResult" do
        result = adapter.void(provider_charge_id: "pay_123")

        expect(result.status).to eq("voided")
      end
    end
  end
end
