module RequestHelpers
  def json_response
    JSON.parse(response.body, symbolize_names: true)
  end

  def auth_headers(api_key)
    { "Authorization" => "Bearer #{api_key}", "Content-Type" => "application/json" }
  end
end

RSpec.configure do |config|
  config.include RequestHelpers, type: :request
end
