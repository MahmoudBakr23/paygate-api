class Refund < ApplicationRecord
  belongs_to :merchant

  STATUSES = %w[pending succeeded failed].freeze
  REASONS  = %w[duplicate fraudulent requested_by_customer].freeze

  validates :amount,  presence: true, numericality: { greater_than: 0, only_integer: true }
  validates :status,  inclusion: { in: STATUSES }
  validates :reason,  inclusion: { in: REASONS }, allow_nil: true
  validates :charge_id, presence: true

  scope :recent, -> { order(created_at: :desc) }
end
