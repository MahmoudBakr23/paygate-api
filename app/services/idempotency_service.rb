class IdempotencyService
  TTL = 24.hours.to_i
  KEY_PREFIX = "idempotency"

  MissingKeyError = Class.new(PaygateError)

  def initialize(merchant_id:, idempotency_key:)
    @merchant_id     = merchant_id
    @idempotency_key = idempotency_key
  end

  # Returns the cached charge_id if this key was already processed, nil otherwise.
  def cached_charge_id
    REDIS.get(redis_key)
  end

  # Stores the charge_id against this idempotency key with a 24h TTL.
  def store!(charge_id)
    REDIS.setex(redis_key, TTL, charge_id)
  end

  def self.require_key!(request)
    key = request.headers["Idempotency-Key"].presence

    unless key
      raise MissingKeyError.new(
        message: "Idempotency-Key header is required for this request",
        code: "missing_idempotency_key",
        status: :unprocessable_content
      )
    end

    key
  end

  private

  def redis_key
    "#{KEY_PREFIX}:#{@merchant_id}:#{@idempotency_key}"
  end
end
