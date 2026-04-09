class AuthService
  JWT_ALGORITHM = "HS256"
  JWT_EXPIRY = 24.hours

  AuthenticationError = Class.new(StandardError)
  InvalidTokenError = Class.new(StandardError)

  RegisterResult = Struct.new(:merchant, :api_key_result, :token, keyword_init: true)
  LoginResult = Struct.new(:merchant, :token, keyword_init: true)
  VerifyResult = Struct.new(:merchant, :jti, :exp, keyword_init: true)

  def register(name:, email:, password:)
    merchant = Merchant.new(name: name, email: email, password: password)
    raise ActiveRecord::RecordInvalid.new(merchant) unless merchant.save

    api_key_result = ApiKeyService.new(merchant: merchant).generate_pair(environment: "sandbox")
    token = issue_token(merchant)

    RegisterResult.new(merchant: merchant, api_key_result: api_key_result, token: token)
  end

  def login(email:, password:)
    merchant = Merchant.find_by(email: email.to_s.downcase)
    raise AuthenticationError, "Invalid credentials" unless merchant&.authenticate(password)

    token = issue_token(merchant)
    LoginResult.new(merchant: merchant, token: token)
  end

  def verify_token(token:)
    payload = JWT.decode(token, jwt_secret, true, algorithm: JWT_ALGORITHM).first

    if REDIS.exists?("jwt:revoked:#{payload['jti']}")
      raise InvalidTokenError, "Token has been revoked"
    end

    merchant = Merchant.find(payload["sub"])
    VerifyResult.new(merchant: merchant, jti: payload["jti"], exp: payload["exp"])
  rescue JWT::ExpiredSignature
    raise InvalidTokenError, "Token has expired"
  rescue JWT::DecodeError => e
    raise InvalidTokenError, "Invalid token: #{e.message}"
  rescue ActiveRecord::RecordNotFound
    raise InvalidTokenError, "Merchant not found"
  end

  def revoke_token(jti:, exp:)
    ttl = exp.to_i - Time.current.to_i
    REDIS.setex("jwt:revoked:#{jti}", ttl, "1") if ttl > 0
  end

  private

  def issue_token(merchant)
    exp = (Time.current + JWT_EXPIRY).to_i
    payload = {
      "sub" => merchant.id,
      "jti" => SecureRandom.uuid,
      "iat" => Time.current.to_i,
      "exp" => exp
    }
    JWT.encode(payload, jwt_secret, JWT_ALGORITHM)
  end

  def jwt_secret
    Rails.application.secret_key_base
  end
end
