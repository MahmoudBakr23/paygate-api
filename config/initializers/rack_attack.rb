class Rack::Attack
  # Cache store backed by Redis
  Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
    url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0")
  )

  # Allow all requests from localhost in development
  safelist("allow-localhost") do |req|
    req.ip == "127.0.0.1" || req.ip == "::1"
  end

  # Block obviously malicious requests
  blocklist("block-bad-user-agents") do |req|
    req.user_agent&.include?("masscan")
  end

  # Global IP throttle: 500 req/min per IP
  throttle("req/ip", limit: 500, period: 1.minute) do |req|
    req.ip unless req.path.start_with?("/health")
  end

  # API key throttle: 100 req/min on charge-mutating endpoints
  throttle("charges/api_key", limit: 100, period: 1.minute) do |req|
    if req.path.start_with?("/v1/charges") && req.post?
      req.get_header("HTTP_AUTHORIZATION")&.split(" ")&.last&.first(16)
    end
  end

  # Login throttle: 10 attempts per 5 min per IP
  throttle("login/ip", limit: 10, period: 5.minutes) do |req|
    req.ip if req.path == "/v1/auth/login" && req.post?
  end

  # Custom response for throttled requests
  self.throttled_responder = lambda do |request|
    retry_after = (request.env["rack.attack.match_data"] || {})[:period]
    [
      429,
      {
        "Content-Type" => "application/json",
        "Retry-After" => retry_after.to_s
      },
      [ { error: "Too many requests. Please retry after #{retry_after} seconds." }.to_json ]
    ]
  end
end
