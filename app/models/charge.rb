class Charge < ApplicationRecord
  # The DB primary key is (id, created_at) due to PostgreSQL partitioning
  # requirements. Rails queries by id alone (WHERE id = ?) which works correctly;
  # partition pruning kicks in when created_at is also in the predicate.
  self.primary_key = "id"

  belongs_to :merchant

  STATUSES = %w[pending authorized captured failed voided refunded].freeze
  PAYMENT_METHODS = %w[card mada apple_pay].freeze
  PROVIDERS = %w[stripe checkout].freeze
  ENVIRONMENTS = %w[sandbox live].freeze

  VALID_TRANSITIONS = {
    "pending"    => %w[authorized failed],
    "authorized" => %w[captured voided failed],
    "captured"   => %w[refunded],
    "failed"     => [],
    "voided"     => [],
    "refunded"   => []
  }.freeze

  validates :amount,         presence: true, numericality: { greater_than: 0, only_integer: true }
  validates :currency,       presence: true, length: { is: 3 }
  validates :payment_method, inclusion: { in: PAYMENT_METHODS }
  validates :status,         inclusion: { in: STATUSES }
  validates :provider,       inclusion: { in: PROVIDERS }
  validates :environment,    inclusion: { in: ENVIRONMENTS }

  scope :for_environment, ->(env) { where(environment: env) }
  scope :recent,          -> { order(created_at: :desc) }

  def transition_to!(new_status)
    allowed = VALID_TRANSITIONS.fetch(status, [])
    unless allowed.include?(new_status)
      raise PaygateError.new(
        message: "Cannot transition charge from '#{status}' to '#{new_status}'",
        status: :unprocessable_content,
        code: "invalid_status_transition"
      )
    end

    attrs = { status: new_status }
    attrs[:captured_at] = Time.current if new_status == "captured"
    update!(attrs)
  end
end
