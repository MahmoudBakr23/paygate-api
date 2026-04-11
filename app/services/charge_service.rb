class ChargeService
  Result = Struct.new(:charge, :replayed, keyword_init: true)

  def initialize(merchant:, idempotency_key:, amount:, currency:, payment_method:, token:, metadata: {})
    @merchant        = merchant
    @idempotency_key = idempotency_key
    @amount          = amount
    @currency        = currency
    @payment_method  = payment_method
    @token           = token
    @metadata        = metadata
  end

  def call
    validate_payment_method!
    validate_live_mode!

    idempotency = IdempotencyService.new(
      merchant_id: @merchant.id,
      idempotency_key: @idempotency_key
    )

    if (cached_id = idempotency.cached_charge_id)
      charge = Charge.find_by!(id: cached_id)
      return Result.new(charge: charge, replayed: true)
    end

    adapter = PaymentRouterService.for(
      payment_method: @payment_method,
      environment: @merchant.environment
    )

    charge = Charge.create!(
      merchant: @merchant,
      amount: @amount,
      currency: @currency,
      payment_method: @payment_method,
      provider: provider_for(@payment_method),
      idempotency_key: @idempotency_key,
      metadata: @metadata,
      environment: @merchant.environment,
      status: "pending"
    )

    adapter_result = adapter.charge(
      amount: @amount,
      currency: @currency,
      token: @token,
      metadata: { charge_id: charge.id, merchant_id: @merchant.id }.merge(@metadata.symbolize_keys)
    )

    charge.update!(
      provider_charge_id: adapter_result.provider_charge_id,
      failure_code: adapter_result.failure_code,
      failure_message: adapter_result.failure_message
    )

    # Auto-capture (adapter returned "captured") must still pass through
    # "authorized" to honour the state machine — pending → authorized → captured.
    if adapter_result.status == "captured"
      charge.transition_to!("authorized")
      charge.transition_to!("captured")
    else
      charge.transition_to!(adapter_result.status)
    end

    idempotency.store!(charge.id)

    Result.new(charge: charge.reload, replayed: false)
  end

  private

  def validate_payment_method!
    unless @merchant.enabled_payment_methods.include?(@payment_method)
      raise PaygateError.new(
        message: "Payment method '#{@payment_method}' is not enabled for this merchant",
        code: "payment_method_disabled",
        status: :unprocessable_content
      )
    end
  end

  def validate_live_mode!
    return unless @merchant.environment == "live"

    raise PaygateError.new(
      message: "Live payment processing is not enabled in this Paygate instance. Use your sandbox keys.",
      code: "live_mode_disabled",
      status: :forbidden
    )
  end

  def provider_for(payment_method)
    PaymentRouterService::ADAPTERS.fetch(payment_method).name.demodulize.sub("Adapter", "").downcase
  end
end
