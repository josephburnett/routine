class UserSetting < ApplicationRecord
  belongs_to :user

  BACKUP_FREQUENCIES = %w[daily weekly monthly].freeze

  validates :backup_method, inclusion: { in: %w[email] }, allow_nil: true
  validates :backup_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, if: :backup_enabled?
  validates :encryption_key, presence: true, if: :backup_enabled?
  validates :backup_frequency, inclusion: { in: BACKUP_FREQUENCIES }

  # Remember decay settings validations
  validates :remember_daily_decay, numericality: { greater_than: 0.0, less_than_or_equal_to: 1.0 }
  validates :remember_min_decay, numericality: { greater_than_or_equal_to: 0.0, less_than: 1.0 }

  before_create :generate_encryption_key, if: :backup_enabled?

  private

  def generate_encryption_key
    self.encryption_key = SecureRandom.base64(32) # 256-bit key
  end
end
