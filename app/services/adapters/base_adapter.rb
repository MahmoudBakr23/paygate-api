module Adapters
  class BaseAdapter
    ChargeResult = Struct.new(
      :provider_charge_id,
      :status,           # "authorized" | "captured" | "failed"
      :failure_code,
      :failure_message,
      keyword_init: true
    )

    RefundResult = Struct.new(
      :provider_refund_id,
      :status,           # "succeeded" | "failed"
      :failure_message,
      keyword_init: true
    )

    VoidResult = Struct.new(
      :status,           # "voided" | "failed"
      :failure_message,
      keyword_init: true
    )

    def initialize(environment:)
      @environment = environment
    end

    def charge(amount:, currency:, token:, metadata: {})
      raise NotImplementedError, "#{self.class}#charge is not implemented"
    end

    def refund(provider_charge_id:, amount:, reason: nil)
      raise NotImplementedError, "#{self.class}#refund is not implemented"
    end

    def void(provider_charge_id:)
      raise NotImplementedError, "#{self.class}#void is not implemented"
    end

    private

    attr_reader :environment

    def sandbox?
      environment == "sandbox"
    end
  end
end
