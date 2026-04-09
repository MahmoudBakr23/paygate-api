Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("CORS_ALLOWED_ORIGINS", "*").split(",")
    resource "*",
      headers: :any,
      methods: %i[get post put patch delete options head],
      expose: %w[X-Request-ID X-RateLimit-Limit X-RateLimit-Remaining]
  end
end
