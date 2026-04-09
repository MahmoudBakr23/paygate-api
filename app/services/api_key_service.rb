class ApiKeyService
  Result = Struct.new(:api_key, :public_key, :secret_key, keyword_init: true)

  # KEY_PREFIX_LENGTH: chars stored for indexed lookup (type 8 + 12 random = 20 total).
  # Remaining 20 chars of the 32-char random portion are bcrypt-verified only.
  KEY_PREFIX_LENGTH = 20

  def initialize(merchant:)
    @merchant = merchant
  end

  def generate_pair(environment:)
    env_label = environment == "sandbox" ? "test" : "live"
    random = SecureRandom.alphanumeric(32).downcase

    public_raw = "pk_#{env_label}_#{random}"
    secret_raw = "sk_#{env_label}_#{SecureRandom.alphanumeric(32).downcase}"

    api_key = ApiKey.create!(
      merchant: @merchant,
      environment: environment,
      public_key: public_raw,
      secret_key_digest: BCrypt::Password.create(secret_raw),
      key_prefix: secret_raw.first(KEY_PREFIX_LENGTH)
    )

    Result.new(api_key: api_key, public_key: public_raw, secret_key: secret_raw)
  end

  def revoke(api_key:)
    raise ArgumentError, "Key belongs to a different merchant" unless api_key.merchant_id == @merchant.id

    api_key.revoke!
  end

  # Class-level — used by the auth concern. No merchant context needed.
  def self.authenticate(raw_key:)
    return nil unless raw_key&.match?(/\Ask_(test|live)_[a-z0-9]{32}\z/)

    prefix = raw_key.first(KEY_PREFIX_LENGTH)
    candidates = ApiKey.active.where(key_prefix: prefix).includes(:merchant)

    candidates.find do |api_key|
      BCrypt::Password.new(api_key.secret_key_digest) == raw_key
    end&.tap do |api_key|
      api_key.update_columns(last_used_at: Time.current)
    end
  end
end
