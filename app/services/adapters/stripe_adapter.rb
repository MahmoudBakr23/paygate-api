module Adapters
  class StripeAdapter < BaseAdapter
    def charge(amount:, currency:, token:, metadata: {})
      payment_method_id = resolve_payment_method(token)

      intent = Stripe::PaymentIntent.create(
        {
          amount: amount,
          currency: currency.downcase,
          payment_method: payment_method_id,
          confirm: true,
          automatic_payment_methods: { enabled: true, allow_redirects: "never" },
          metadata: metadata
        },
        { api_key: api_key }
      )

      if intent.status == "requires_action"
        return ChargeResult.new(
          provider_charge_id: intent.id,
          status: "failed",
          failure_code: "requires_action",
          failure_message: "This card requires 3D Secure authentication, which is not supported in server-side-only mode."
        )
      end

      ChargeResult.new(
        provider_charge_id: intent.id,
        status: map_intent_status(intent.status),
        failure_code: nil,
        failure_message: nil
      )
    rescue Stripe::CardError => e
      ChargeResult.new(
        provider_charge_id: e.error.payment_intent&.id,
        status: "failed",
        failure_code: e.code,
        failure_message: e.message
      )
    rescue Stripe::InvalidRequestError, Stripe::AuthenticationError,
           Stripe::APIConnectionError, Stripe::StripeError => e
      raise PaygateError.new(
        message: "Stripe error: #{e.message}",
        code: "provider_error",
        status: :bad_gateway
      )
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
      raise PaygateError.new(
        message: "Stripe connection error: #{e.message}",
        code: "provider_error",
        status: :bad_gateway
      )
    end

    def refund(provider_charge_id:, amount:, reason: nil)
      params = { payment_intent: provider_charge_id, amount: amount }
      params[:reason] = reason if reason.present?

      stripe_refund = Stripe::Refund.create(params, { api_key: api_key })

      RefundResult.new(
        provider_refund_id: stripe_refund.id,
        status: stripe_refund.status == "succeeded" ? "succeeded" : "failed",
        failure_message: nil
      )
    rescue Stripe::InvalidRequestError => e
      RefundResult.new(
        provider_refund_id: nil,
        status: "failed",
        failure_message: e.message
      )
    rescue Stripe::StripeError => e
      raise PaygateError.new(
        message: "Stripe refund error: #{e.message}",
        code: "provider_error",
        status: :bad_gateway
      )
    end

    def void(provider_charge_id:)
      intent = Stripe::PaymentIntent.cancel(provider_charge_id, {}, { api_key: api_key })

      VoidResult.new(
        status: intent.status == "canceled" ? "voided" : "failed",
        failure_message: nil
      )
    rescue Stripe::InvalidRequestError => e
      VoidResult.new(status: "failed", failure_message: e.message)
    rescue Stripe::StripeError => e
      raise PaygateError.new(
        message: "Stripe void error: #{e.message}",
        code: "provider_error",
        status: :bad_gateway
      )
    end

    private

    # tok_... (legacy token from Stripe.js createToken) must be converted to a
    # PaymentMethod ID (pm_...) before it can be attached to a PaymentIntent.
    def resolve_payment_method(token)
      return token if token.start_with?("pm_")

      pm = Stripe::PaymentMethod.create(
        { type: "card", card: { token: token } },
        { api_key: api_key }
      )
      pm.id
    end

    def api_key
      if sandbox?
        ENV.fetch("STRIPE_SANDBOX_SECRET_KEY")
      else
        ENV.fetch("STRIPE_LIVE_SECRET_KEY")
      end
    end

    def map_intent_status(status)
      case status
      when "succeeded"                 then "captured"
      when "requires_capture"          then "authorized"
      when "requires_payment_method",
           "canceled"                  then "failed"
      else                                  "pending"
      end
    end
  end
end
