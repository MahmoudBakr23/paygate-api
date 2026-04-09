class ApplicationController < ActionController::API
  before_action :set_request_id

  private

  def set_request_id
    request_id = request.headers["X-Request-ID"] || SecureRandom.uuid
    response.set_header("X-Request-ID", request_id)
    Thread.current[:request_id] = request_id
  end

  def render_error(status:, code:, message:)
    render json: { error: { code: code, message: message } }, status: status
  end
end
