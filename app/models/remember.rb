class Remember < ApplicationRecord
  include Namespaceable

  STATES = %w[pinned floating retired].freeze

  belongs_to :user

  validates :description, presence: true
  validates :state, presence: true, inclusion: { in: STATES }
  validates :decay, presence: true,
                    numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }

  scope :not_deleted, -> { where(deleted: false) }
  scope :pinned, -> { where(state: "pinned") }
  scope :floating, -> { where(state: "floating") }
  scope :retired, -> { where(state: "retired") }
  scope :active, -> { where(state: %w[pinned floating]) }

  def soft_delete!
    update!(deleted: true)
  end

  # Determines if this remember should be visible today
  # Uses a seeded hash to ensure stable visibility per day
  def visible_today?
    return true if state == "pinned"
    return false if state == "retired" || decay == 0.0

    # Create a daily seed from the Remember ID and today's date
    daily_seed = "#{id}-#{Date.current}".hash.abs

    # Normalize to 0.0-1.0 range
    threshold = (daily_seed % 10000) / 10000.0

    # Compare against decay - higher decay = higher chance of showing
    threshold < decay
  end

  # Apply daily decay with jitter to prevent thundering herd
  # - Adds random jitter to decay amount (±jitter%)
  # - Stops decaying at personal_decay_floor (between soft and hard min)
  # - Hard minimum is an invariant floor
  def apply_decay!
    return if state == "pinned" || state == "retired"

    settings = user.user_setting
    daily_decay = settings&.remember_daily_decay || 0.05
    hard_min = settings&.remember_min_decay || 0.01
    jitter = settings&.remember_decay_jitter || 0.2

    # Stop decaying if we've reached this remember's personal floor
    return if decay <= personal_decay_floor

    # Apply jittered decay: vary by ±jitter (e.g., ±20%)
    jitter_factor = 1.0 + (rand * 2 - 1) * jitter
    actual_decay = daily_decay * jitter_factor

    # Clamp to hard minimum (invariant)
    new_decay = [ decay - actual_decay, hard_min ].max
    update!(decay: new_decay)
  end

  # Each remember has a personal floor between hard_min and soft_min
  # Based on ID hash for stable, distributed stopping points
  def personal_decay_floor
    settings = user.user_setting
    hard_min = settings&.remember_min_decay || 0.01
    soft_min = settings&.remember_soft_min_decay || 0.05

    # Create a stable value between 0 and 1 based on this remember's ID
    hash_value = (id.to_s.hash.abs % 10000) / 10000.0

    # Interpolate between hard_min and soft_min
    hard_min + (soft_min - hard_min) * hash_value
  end

  # Pin this remember - always visible at top
  def pin!
    update!(state: "pinned", decay: 1.0)
  end

  # Bump up - double the decay (max 1.0), set to floating
  def bump_up!
    new_decay = [ decay * 2, 1.0 ].min
    update!(state: "floating", decay: new_decay)
  end

  # Bump down - halve the decay (min from user settings), set to floating if not already
  def bump_down!
    min_decay = user.user_setting&.remember_min_decay || 0.01
    new_decay = [ decay / 2, min_decay ].max
    update!(decay: new_decay)
    update!(state: "floating") unless state == "retired"
  end

  # Retire this remember - no longer shown
  def retire!
    update!(state: "retired", decay: 0.0)
  end

  # Sort by decay descending (pinned=1.0 at top, retired=0.0 at bottom)
  def self.sorted_by_decay
    order(decay: :desc)
  end

  # Get items in namespace and all child namespaces
  # e.g., "home" matches "home", "home.chores", "home.chores.weekly"
  def self.in_namespace_recursive(user, namespace = "")
    if namespace.blank?
      where(user: user)
    else
      where(user: user)
        .where("namespace = ? OR namespace LIKE ?", namespace, "#{namespace}.%")
    end
  end

  # Get visible remembers for today in namespace and all child namespaces
  def self.visible_today_recursive(user, namespace = "")
    in_namespace_recursive(user, namespace)
      .not_deleted
      .active
      .sorted_by_decay
      .select(&:visible_today?)
  end
end
