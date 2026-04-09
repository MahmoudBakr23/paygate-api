class ApiKey < ApplicationRecord
  belongs_to :merchant

  ENVIRONMENTS = %w[sandbox live].freeze

  validates :environment, inclusion: { in: ENVIRONMENTS }
  validates :public_key, presence: true, uniqueness: true
  validates :secret_key_digest, presence: true
  validates :key_prefix, presence: true

  scope :active, -> { where(revoked_at: nil) }
  scope :for_environment, ->(env) { where(environment: env) }

  def active?
    revoked_at.nil?
  end

  def revoke!
    update!(revoked_at: Time.current)
  end
end
