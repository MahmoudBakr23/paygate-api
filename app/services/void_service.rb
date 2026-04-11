class VoidService
  Result = Struct.new(:charge, keyword_init: true)

  def initialize(merchant:, charge:)
    @merchant = merchant
    @charge   = charge
  end

  def call
    validate_charge_ownership!
    validate_voidable!

    adapter = PaymentRouterService.for(
      payment_method: @charge.payment_method,
      environment: @merchant.environment
    )

    adapter_result = adapter.void(provider_charge_id: @charge.provider_charge_id)

    if adapter_result.status == "voided"
      @charge.transition_to!("voided")
      LedgerService.record_void(charge: @charge)
      WebhookDispatcherService.dispatch(event_type: "charge.voided", charge: @charge.reload, refund: nil, merchant: @merchant)
    else
      raise PaygateError.new(
        message: adapter_result.failure_message || "Void failed at provider",
        code: "provider_void_failed",
        status: :bad_gateway
      )
    end

    Result.new(charge: @charge.reload)
  end

  private

  def validate_charge_ownership!
    return if @charge.merchant_id == @merchant.id

    raise PaygateError.new(
      message: "Charge not found",
      code: "not_found",
      status: :not_found
    )
  end

  def validate_voidable!
    return if @charge.status == "authorized"

    raise PaygateError.new(
      message: "Only authorized charges can be voided",
      code: "invalid_charge_status",
      status: :unprocessable_content
    )
  end
end
