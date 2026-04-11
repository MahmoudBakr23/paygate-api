class ProviderWebhookProcessorJob < ApplicationJob
  queue_as :default

  def perform(provider, payload_json, signature)
    case provider
    when "stripe"
      process_stripe(payload_json, signature)
    when "checkout"
      process_checkout(payload_json, signature)
    else
      Rails.logger.warn(event: "unknown_provider_webhook", provider: provider)
    end
  end

  private

  def process_stripe(payload_json, signature)
    event = verify_stripe_signature(payload_json, signature)
    return unless event

    case event["type"]
    when "payment_intent.succeeded"
      handle_stripe_payment_succeeded(event["data"]["object"])
    when "payment_intent.payment_failed"
      handle_stripe_payment_failed(event["data"]["object"])
    when "charge.refunded"
      handle_stripe_charge_refunded(event["data"]["object"])
    else
      Rails.logger.info(event: "stripe_webhook_unhandled", type: event["type"])
    end
  end

  def process_checkout(payload_json, signature)
    event = verify_checkout_signature(payload_json, signature)
    return unless event

    case event["type"]
    when "payment_approved"
      handle_checkout_payment_approved(event["data"])
    when "payment_declined"
      handle_checkout_payment_declined(event["data"])
    else
      Rails.logger.info(event: "checkout_webhook_unhandled", type: event["type"])
    end
  end

  def verify_stripe_signature(payload_json, signature)
    secret = ENV.fetch("STRIPE_SANDBOX_WEBHOOK_SECRET", nil)
    unless secret
      Rails.logger.error(event: "stripe_webhook_secret_missing")
      return nil
    end

    # Stripe signature format: t=timestamp,v1=computed_hmac
    # Each component is key=value; skip malformed parts
    parts = {}
    signature.to_s.split(",").each do |component|
      key, value = component.split("=", 2)
      parts[key] = value if key && value
    end

    timestamp = parts["t"]
    v1        = parts["v1"]

    if timestamp.nil? || v1.nil?
      Rails.logger.warn(event: "stripe_webhook_invalid_signature_format")
      return nil
    end

    signed_payload = "#{timestamp}.#{payload_json}"
    expected       = OpenSSL::HMAC.hexdigest("SHA256", secret, signed_payload)

    unless ActiveSupport::SecurityUtils.secure_compare(expected, v1)
      Rails.logger.warn(event: "stripe_webhook_signature_mismatch")
      return nil
    end

    JSON.parse(payload_json)
  rescue JSON::ParserError
    Rails.logger.warn(event: "stripe_webhook_invalid_json")
    nil
  end

  def verify_checkout_signature(payload_json, signature)
    secret = ENV.fetch("CHECKOUT_SANDBOX_WEBHOOK_SECRET", nil)
    unless secret
      Rails.logger.error(event: "checkout_webhook_secret_missing")
      return nil
    end

    expected = OpenSSL::HMAC.hexdigest("SHA256", secret, payload_json)
    unless ActiveSupport::SecurityUtils.secure_compare(expected, signature.to_s)
      Rails.logger.warn(event: "checkout_webhook_signature_mismatch")
      return nil
    end

    JSON.parse(payload_json)
  rescue JSON::ParserError
    Rails.logger.warn(event: "checkout_webhook_invalid_json")
    nil
  end

  def handle_stripe_payment_succeeded(payment_intent)
    provider_charge_id = payment_intent["id"]
    charge = Charge.find_by(provider_charge_id: provider_charge_id)
    return unless charge

    return if charge.status == "captured"

    if charge.status == "pending"
      charge.transition_to!("authorized")
    end
    charge.transition_to!("captured")
    LedgerService.record_captured_charge(charge: charge)
    WebhookDispatcherService.dispatch(
      event_type: "charge.captured",
      charge: charge,
      refund: nil,
      merchant: charge.merchant
    )
  end

  def handle_stripe_payment_failed(payment_intent)
    provider_charge_id = payment_intent["id"]
    charge = Charge.find_by(provider_charge_id: provider_charge_id)
    return unless charge

    return unless %w[pending authorized].include?(charge.status)

    charge.transition_to!("failed")
    WebhookDispatcherService.dispatch(
      event_type: "charge.failed",
      charge: charge,
      refund: nil,
      merchant: charge.merchant
    )
  end

  def handle_stripe_charge_refunded(stripe_charge)
    # Stripe charge objects contain refund data
    payment_intent_id = stripe_charge["payment_intent"]
    charge = Charge.find_by(provider_charge_id: payment_intent_id)
    return unless charge

    return if charge.status == "refunded"

    charge.transition_to!("refunded") if charge.status == "captured"
    WebhookDispatcherService.dispatch(
      event_type: "refund.succeeded",
      charge: charge,
      refund: nil,
      merchant: charge.merchant
    )
  end

  def handle_checkout_payment_approved(data)
    provider_charge_id = data["id"]
    charge = Charge.find_by(provider_charge_id: provider_charge_id)
    return unless charge

    return if charge.status == "captured"

    charge.transition_to!("authorized") if charge.status == "pending"
    charge.transition_to!("captured")
    LedgerService.record_captured_charge(charge: charge)
    WebhookDispatcherService.dispatch(
      event_type: "charge.captured",
      charge: charge,
      refund: nil,
      merchant: charge.merchant
    )
  end

  def handle_checkout_payment_declined(data)
    provider_charge_id = data["id"]
    charge = Charge.find_by(provider_charge_id: provider_charge_id)
    return unless charge

    return unless %w[pending authorized].include?(charge.status)

    charge.transition_to!("failed")
    WebhookDispatcherService.dispatch(
      event_type: "charge.failed",
      charge: charge,
      refund: nil,
      merchant: charge.merchant
    )
  end
end
