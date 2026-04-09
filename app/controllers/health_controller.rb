class HealthController < ApplicationController
  skip_before_action :set_request_id

  def liveness
    render json: { status: "ok" }, status: :ok
  end

  def readiness
    checks = {
      db: database_connected?,
      redis: redis_connected?,
      sidekiq: sidekiq_connected?
    }

    status = checks.values.all? ? :ok : :service_unavailable
    render json: { status: status == :ok ? "ok" : "degraded", checks: checks }, status: status
  end

  private

  def database_connected?
    ActiveRecord::Base.connection.execute("SELECT 1")
    true
  rescue StandardError
    false
  end

  def redis_connected?
    REDIS.ping == "PONG"
  rescue StandardError
    false
  end

  def sidekiq_connected?
    Sidekiq.redis { |conn| conn.call("PING") == "PONG" }
  rescue StandardError
    false
  end
end
