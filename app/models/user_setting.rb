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
  validates :remember_soft_min_decay, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }
  validates :remember_decay_jitter, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }
  validate :soft_min_greater_than_hard_min

  before_create :generate_encryption_key, if: :backup_enabled?

  private

  def soft_min_greater_than_hard_min
    return unless remember_soft_min_decay && remember_min_decay
    if remember_soft_min_decay < remember_min_decay
      errors.add(:remember_soft_min_decay, "must be greater than or equal to hard minimum (remember_min_decay)")
    end
  end

  def generate_encryption_key
    self.encryption_key = SecureRandom.base64(32) # 256-bit key
  end
end
