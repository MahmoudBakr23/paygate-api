require "net/http"
require "json"

module Adapters
  # Checkout.com adapter using the Checkout.com API directly (REST).
  # Handles Mada payments routed through Checkout.com's sandbox/live environments.
  class CheckoutAdapter < BaseAdapter
    BASE_URL_SANDBOX = "https://api.sandbox.checkout.com"
    BASE_URL_LIVE    = "https://api.checkout.com"

    def charge(amount:, currency:, token:, metadata: {})
      payload = {
        source: { type: "token", token: token },
        amount: amount,
        currency: currency.upcase,
        capture: true,
        reference: metadata[:reference] || SecureRandom.uuid,
        metadata: metadata
      }

      response = post("/payments", payload)
      body = JSON.parse(response.body, symbolize_names: true)

      if response.code.to_i == 201
        ChargeResult.new(
          provider_charge_id: body[:id],
          status: map_checkout_status(body[:status]),
          failure_code: nil,
          failure_message: nil
        )
      else
        ChargeResult.new(
          provider_charge_id: nil,
          status: "failed",
          failure_code: body.dig(:error_codes, 0) || "checkout_error",
          failure_message: body[:message] || "Payment declined"
        )
      end
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED => e
      raise PaygateError.new(
        message: "Checkout.com connection error: #{e.message}",
        code: "provider_error",
        status: :bad_gateway
      )
    end

    def refund(provider_charge_id:, amount:, reason: nil)
      payload = { amount: amount, reference: SecureRandom.uuid }

      response = post("/payments/#{provider_charge_id}/refunds", payload)
      body = JSON.parse(response.body, symbolize_names: true)

      if response.code.to_i == 202
        RefundResult.new(
          provider_refund_id: body[:action_id],
          status: "succeeded",
          failure_message: nil
        )
      else
        RefundResult.new(
          provider_refund_id: nil,
          status: "failed",
          failure_message: body[:message] || "Refund failed"
        )
      end
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED => e
      raise PaygateError.new(
        message: "Checkout.com connection error: #{e.message}",
        code: "provider_error",
        status: :bad_gateway
      )
    end

    def void(provider_charge_id:)
      response = post("/payments/#{provider_charge_id}/voids", {})
      body = JSON.parse(response.body, symbolize_names: true)

      if response.code.to_i == 202
        VoidResult.new(status: "voided", failure_message: nil)
      else
        VoidResult.new(status: "failed", failure_message: body[:message] || "Void failed")
      end
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED => e
      raise PaygateError.new(
        message: "Checkout.com connection error: #{e.message}",
        code: "provider_error",
        status: :bad_gateway
      )
    end

    private

    def post(path, payload)
      uri = URI("#{base_url}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 30

      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{api_key}"
      request["Content-Type"]  = "application/json"
      request.body = payload.to_json

      http.request(request)
    end

    def base_url
      sandbox? ? BASE_URL_SANDBOX : BASE_URL_LIVE
    end

    def api_key
      if sandbox?
        ENV.fetch("CHECKOUT_SANDBOX_SECRET_KEY")
      else
        ENV.fetch("CHECKOUT_LIVE_SECRET_KEY")
      end
    end

    def map_checkout_status(status)
      case status
      when "Authorized"          then "authorized"
      when "Captured", "Paid"   then "captured"
      when "Declined", "Expired" then "failed"
      else                            "pending"
      end
    end
  end
end
