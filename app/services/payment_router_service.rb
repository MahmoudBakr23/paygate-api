class PaymentRouterService
  ADAPTERS = {
    "card"      => Adapters::StripeAdapter,
    "apple_pay" => Adapters::StripeAdapter,
    "mada"      => Adapters::CheckoutAdapter
  }.freeze

  UnknownPaymentMethod = Class.new(PaygateError)

  def self.for(payment_method:, environment:)
    adapter_class = ADAPTERS[payment_method]

    unless adapter_class
      raise UnknownPaymentMethod.new(
        message: "Unsupported payment method: #{payment_method}. Supported: #{ADAPTERS.keys.join(', ')}",
        code: "unsupported_payment_method",
        status: :unprocessable_content
      )
    end

    adapter_class.new(environment: environment)
  end
end
