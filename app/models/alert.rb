class Alert < ApplicationRecord
  include Namespaceable

  belongs_to :user
  belongs_to :metric
  has_one :alert_status_cache, dependent: :destroy

  has_many :report_alerts, dependent: :destroy
  has_many :reports, through: :report_alerts

  validates :name, presence: true
  validates :threshold, presence: true, numericality: true
  validates :direction, presence: true, inclusion: { in: %w[above below at_or_above at_or_below] }
  validates :delay, presence: true, numericality: { greater_than: 0, only_integer: true }

  scope :not_deleted, -> { where(deleted: false) }
  scope :enabled, -> { where(disabled: false) }

  def soft_delete!
    update!(deleted: true)
  end

  def activated?
    # Disabled alerts are never activated
    return false if disabled?

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
    return [ false, nil ] unless metric&.series&.any?

    series_data = metric.series
    return [ false, nil ] if series_data.length < delay

    # Get the last 'delay' number of data points
    recent_values = series_data.last(delay).map(&:last)
    return [ false, nil ] if recent_values.any?(&:nil?)

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
    when "at_or_above"
      # For activation: all values must be at or above threshold
      # For deactivation: any value below threshold deactivates
      recent_values.all? { |value| value >= threshold }
    when "at_or_below"
      # For activation: all values must be at or below threshold
      # For deactivation: any value above threshold deactivates
      recent_values.all? { |value| value <= threshold }
    else
      false
    end

    [ is_activated, current_value ]
  end

  def activation_progress
    return { progress: 0.0, exceeding_count: 0, total_count: delay } unless metric&.series&.any?

    series_data = metric.series
    return { progress: 0.0, exceeding_count: 0, total_count: delay } if series_data.length < delay

    # Get the last 'delay' number of data points
    recent_values = series_data.last(delay).map(&:last)
    return { progress: 0.0, exceeding_count: 0, total_count: delay } if recent_values.any?(&:nil?)

    # Count how many recent values exceed the threshold
    exceeding_count = case direction
    when "above"
      recent_values.count { |value| value > threshold }
    when "below"
      recent_values.count { |value| value < threshold }
    when "at_or_above"
      recent_values.count { |value| value >= threshold }
    when "at_or_below"
      recent_values.count { |value| value <= threshold }
    else
      0
    end

    # Find the most recent non-exceeding value (if any)
    # Only count consecutive exceeding values from the end
    consecutive_exceeding = 0
    recent_values.reverse.each do |value|
      exceeds = case direction
      when "above"
        value > threshold
      when "below"
        value < threshold
      when "at_or_above"
        value >= threshold
      when "at_or_below"
        value <= threshold
      else
        false
      end

      if exceeds
        consecutive_exceeding += 1
      else
        break # Stop at first non-exceeding value
      end
    end

    exceeding_count = consecutive_exceeding

    progress = exceeding_count.to_f / delay.to_f
    { progress: progress, exceeding_count: exceeding_count, total_count: delay }
  end

  def status_color
    return "#999" if disabled?
    activated? ? "red" : "green"
  end

  def status_text
    return "Disabled" if disabled?
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
