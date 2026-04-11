require "rails_helper"

RSpec.describe PaymentRouterService do
  describe ".for" do
    it "returns a StripeAdapter for card" do
      adapter = described_class.for(payment_method: "card", environment: "sandbox")
      expect(adapter).to be_a(Adapters::StripeAdapter)
    end

    it "returns a StripeAdapter for apple_pay" do
      adapter = described_class.for(payment_method: "apple_pay", environment: "sandbox")
      expect(adapter).to be_a(Adapters::StripeAdapter)
    end

    it "returns a CheckoutAdapter for mada" do
      adapter = described_class.for(payment_method: "mada", environment: "sandbox")
      expect(adapter).to be_a(Adapters::CheckoutAdapter)
    end

    it "raises PaygateError for unknown payment method" do
      expect {
        described_class.for(payment_method: "bitcoin", environment: "sandbox")
      }.to raise_error(PaygateError) { |e|
        expect(e.code).to eq("unsupported_payment_method")
        expect(e.status).to eq(:unprocessable_content)
      }
    end
  end
end
