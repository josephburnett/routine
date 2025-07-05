class Alert < ApplicationRecord
  include Namespaceable

  belongs_to :user
  belongs_to :metric
  has_one :alert_status_cache, dependent: :destroy

  has_many :report_alerts, dependent: :destroy
  has_many :reports, through: :report_alerts

  validates :name, presence: true
  validates :threshold, presence: true, numericality: true
  validates :direction, presence: true, inclusion: { in: %w[above below] }
  validates :delay, presence: true, numericality: { greater_than: 0, only_integer: true }

  scope :not_deleted, -> { where(deleted: false) }

  def soft_delete!
    update!(deleted: true)
  end

  def activated?
    # Use cached data if available and fresh
    if alert_status_cache&.fresh?
      return alert_status_cache.is_activated
    end

    # Otherwise calculate, cache, and return
    is_activated, _current_value = calculate_status_uncached
    AlertStatusCache.update_for_alert(self)
    is_activated
  end

  def calculate_status_uncached
    return [false, nil] unless metric&.series&.any?

    series_data = metric.series
    return [false, nil] if series_data.length < delay

    # Get the last 'delay' number of data points
    recent_values = series_data.last(delay).map(&:last)
    return [false, nil] if recent_values.any?(&:nil?)

    # Get current value (most recent)
    current_value = recent_values.last

    # Check if ALL recent values are outside the threshold (activation condition)
    # OR if ANY recent value is inside the threshold (deactivation condition)
    is_activated = case direction
    when "above"
      # For activation: all values must be above threshold
      # For deactivation: any value below or equal to threshold deactivates
      recent_values.all? { |value| value > threshold }
    when "below"
      # For activation: all values must be below threshold
      # For deactivation: any value above or equal to threshold deactivates
      recent_values.all? { |value| value < threshold }
    else
      false
    end

    [is_activated, current_value]
  end

  def status_color
    activated? ? "red" : "green"
  end

  def status_text
    activated? ? "Activated" : "Deactivated"
  end

  def display_name
    if name.present?
      name
    else
      id_display = id ? "##{id}" : "(New)"
      "Alert #{id_display}"
    end
  end

  def display_title
    "#{metric.display_name}: #{display_name}"
  end
end
