class RefundService
  Result = Struct.new(:refund, keyword_init: true)

  REFUNDABLE_STATUSES = %w[captured].freeze

  def initialize(merchant:, charge:, amount:, reason: nil)
    @merchant = merchant
    @charge   = charge
    @amount   = amount
    @reason   = reason
  end

  def call
    validate_charge_ownership!
    validate_refundable!
    validate_amount!

    adapter = PaymentRouterService.for(
      payment_method: @charge.payment_method,
      environment: @merchant.environment
    )

    refund = Refund.create!(
      merchant: @merchant,
      charge_id: @charge.id,
      amount: @amount,
      reason: @reason,
      status: "pending"
    )

    adapter_result = adapter.refund(
      provider_charge_id: @charge.provider_charge_id,
      amount: @amount,
      reason: @reason
    )

    refund.update!(
      provider_refund_id: adapter_result.provider_refund_id,
      status: adapter_result.status
    )

    handle_successful_refund(refund) if adapter_result.status == "succeeded"

    Result.new(refund: refund.reload)
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

  def validate_refundable!
    return if REFUNDABLE_STATUSES.include?(@charge.status)

    raise PaygateError.new(
      message: "Charge cannot be refunded in status '#{@charge.status}'",
      code: "invalid_charge_status",
      status: :unprocessable_content
    )
  end

  def validate_amount!
    if @amount <= 0
      raise PaygateError.new(
        message: "Refund amount must be greater than zero",
        code: "invalid_amount",
        status: :unprocessable_content
      )
    end

    refunded_amount = @charge.refunds.where(status: "succeeded").sum(:amount)
    if refunded_amount + @amount > @charge.amount
      raise PaygateError.new(
        message: "Refund amount exceeds the remaining refundable amount",
        code: "amount_exceeds_charge",
        status: :unprocessable_content
      )
    end
  end

  def handle_successful_refund(refund)
    refunded_amount = @charge.refunds.where(status: "succeeded").sum(:amount)
    @charge.transition_to!("refunded") if refunded_amount >= @charge.amount
    LedgerService.record_refund(charge: @charge, refund: refund)
  end
end
