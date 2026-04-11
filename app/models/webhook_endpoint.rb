class WebhookEndpoint < ApplicationRecord
  VALID_EVENTS = %w[
    charge.pending charge.authorized charge.captured charge.failed charge.voided
    refund.created refund.succeeded refund.failed
  ].freeze

  belongs_to :merchant
  has_many :webhook_deliveries, dependent: :destroy

  validates :url, presence: true, format: { with: /\Ahttps?:\/\/.+\z/, message: "must be a valid URL" }
  validates :events, presence: true
  validate :events_are_valid

  before_create :generate_webhook_secret

  scope :active, -> { where(active: true) }
  scope :subscribed_to, ->(event_type) { active.where("events @> ARRAY[?]::varchar[]", event_type) }

  private

  def events_are_valid
    invalid = Array(events) - VALID_EVENTS
    errors.add(:events, "contains invalid event types: #{invalid.join(', ')}") if invalid.any?
  end

  def generate_webhook_secret
    self.webhook_secret = "whsec_#{SecureRandom.hex(24)}"
  end
end
