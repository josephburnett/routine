# A bearer token for the MCP endpoint. Only a SHA-256 digest is stored; the
# plain token is shown once, when it's created.
class ApiToken < ApplicationRecord
  PREFIX = "rt_".freeze

  belongs_to :user

  validates :name, presence: true
  validates :token_digest, presence: true, uniqueness: true

  scope :active, -> { where(revoked_at: nil) }

  # Returns [api_token, plain_token].
  def self.issue!(user:, name:)
    plain = PREFIX + SecureRandom.base58(32)
    token = create!(user: user, name: name, token_digest: digest(plain))
    [ token, plain ]
  end

  # The active token matching the plain token, or nil.
  def self.authenticate(plain)
    return nil if plain.blank?

    token = active.find_by(token_digest: digest(plain))
    token&.touch_last_used
    token
  end

  def self.digest(plain)
    Digest::SHA256.hexdigest(plain.to_s)
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def touch_last_used
    # Once a minute is plenty, and saves a write per request
    update_column(:last_used_at, Time.current) if last_used_at.nil? || last_used_at < 1.minute.ago
  end
end
