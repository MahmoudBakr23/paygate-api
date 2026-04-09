Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.base_controller_class = "ActionController::API"

  config.lograge.formatter = Lograge::Formatters::Json.new

  config.lograge.custom_options = lambda do |event|
    {
      request_id: event.payload[:request_id],
      merchant_id: event.payload[:merchant_id],
      environment: event.payload[:environment],
      params: event.payload[:params]&.except("controller", "action", "format")
    }.compact
  end
end
