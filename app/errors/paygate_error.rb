class PaygateError < StandardError
  attr_reader :status, :code

  def initialize(message:, status: :unprocessable_entity, code: "error")
    super(message)
    @status = status
    @code = code
  end
end
