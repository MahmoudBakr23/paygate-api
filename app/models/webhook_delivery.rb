class WebhookDelivery < ApplicationRecord
  STATUSES = %w[pending delivered failed retrying].freeze
  MAX_ATTEMPTS = 5
  RETRY_DELAYS = [5.minutes, 30.minutes, 2.hours, 24.hours].freeze

  belongs_to :webhook_endpoint

  validates :event_type, presence: true
  validates :payload, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :pending_retry, -> { where(status: "retrying").where("next_retry_at <= ?", Time.current) }

  def next_retry_delay
    RETRY_DELAYS[attempts] || RETRY_DELAYS.last
  end

  def retries_exhausted?
    attempts >= MAX_ATTEMPTS
  end
end
