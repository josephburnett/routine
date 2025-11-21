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

  # Apply daily decay - multiply by 0.8, minimum 0.01
  def apply_decay!
    return if state == "pinned" || state == "retired"

    new_decay = [ decay * 0.8, 0.01 ].max
    update!(decay: new_decay)
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

  # Bump down - halve the decay (min 0.01), set to floating if not already
  def bump_down!
    new_decay = [ decay / 2, 0.01 ].max
    update!(decay: new_decay)
    update!(state: "floating") unless state == "retired"
  end

  # Retire this remember - no longer shown
  def retire!
    update!(state: "retired", decay: 0.0)
  end

  # Sort order: pinned first, then by decay descending
  def self.sorted_by_visibility
    order(
      Arel.sql("CASE WHEN state = 'pinned' THEN 0 ELSE 1 END"),
      decay: :desc
    )
  end

  # Get visible remembers for today
  def self.visible_today_for_user(user, namespace = "")
    items_in_namespace(user, namespace)
      .not_deleted
      .active
      .sorted_by_visibility
      .select(&:visible_today?)
  end
end
