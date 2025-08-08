class Report < ApplicationRecord
  include Namespaceable

  belongs_to :user

  # JSON attributes
  attribute :interval_config, :json

  # Many-to-many relationships
  has_many :report_alerts, dependent: :destroy
  has_many :alerts, through: :report_alerts

  has_many :report_metrics, dependent: :destroy
  has_many :metrics, through: :report_metrics

  validates :name, presence: true
  validates :time_of_day, presence: true, unless: -> { interval_type == "none" }
  validates :interval_type, presence: true, inclusion: { in: %w[weekly monthly none] }
  validates :interval_config, presence: true, unless: -> { interval_type == "none" }

  validate :validate_interval_config

  scope :not_deleted, -> { where(deleted: false) }

  def soft_delete!
    update!(deleted: true)
  end

  # Class method to send all due reports
  def self.send_due_reports!
    Report.not_deleted.where.not(interval_type: "none").find_each do |report|
      if report.should_send_now?
        begin
          ReportMailer.scheduled_report(report).deliver_now
          report.update!(last_sent_at: Time.current)
          Rails.logger.info "Sent report: #{report.name} (ID: #{report.id})"
        rescue => e
          Rails.logger.error "Failed to send report #{report.name} (ID: #{report.id}): #{e.message}"
        end
      end
    end
  end

  # Check if this report should be sent now
  def should_send_now?
    return false if interval_type == "none"
    return false unless next_send_time_passed?
    return false unless has_content_to_send?
    true
  end

  # Get active alerts for this report
  def active_alerts
    alerts.select(&:activated?)
  end

  # Check if report has content to send
  def has_content_to_send?
    # Has active alerts OR has metrics
    active_alerts.any? || metrics.any?
  end

  # Get next scheduled send time
  def next_send_time
    return nil if interval_type == "none"
    return nil unless time_of_day && interval_type && interval_config

    base_time = Time.current.beginning_of_day + time_of_day.seconds_since_midnight.seconds

    case interval_type
    when "weekly"
      days = interval_config["days"] || []
      return nil if days.empty?

      # Find next occurrence
      (0..7).each do |days_ahead|
        candidate_time = base_time + days_ahead.days
        if days.include?(candidate_time.strftime("%A").downcase) && candidate_time > Time.current
          return candidate_time
        end
      end

    when "monthly"
      day_of_month = interval_config["day_of_month"]&.to_i
      return nil unless day_of_month

      # This month if not past
      candidate_time = base_time.change(day: day_of_month)
      return candidate_time if candidate_time > Time.current

      # Next month
      return candidate_time + 1.month
    end

    nil
  end

  private

  def next_send_time_passed?
    return true unless last_sent_at

    # Check if enough time has passed since last sent based on interval
    case interval_type
    when "weekly"
      days = interval_config["days"] || []
      return false if days.empty?

      # Check if today is a scheduled day and enough time has passed
      today = Time.current.strftime("%A").downcase
      return false unless days.include?(today)

      # Check if we've passed the scheduled time today
      scheduled_time_today = Time.current.beginning_of_day + time_of_day.seconds_since_midnight.seconds
      return false if Time.current < scheduled_time_today

      # Check if we already sent today
      return false if last_sent_at && last_sent_at.to_date == Time.current.to_date

      true
    when "monthly"
      day_of_month = interval_config["day_of_month"]&.to_i
      return false unless day_of_month

      # Check if today is the scheduled day and enough time has passed
      return false unless Time.current.day == day_of_month

      # Check if we've passed the scheduled time today
      scheduled_time_today = Time.current.beginning_of_day + time_of_day.seconds_since_midnight.seconds
      return false if Time.current < scheduled_time_today

      # Check if we already sent this month
      return false if last_sent_at && last_sent_at.month == Time.current.month && last_sent_at.year == Time.current.year

      true
    else
      false
    end
  end

  def validate_interval_config
    return unless interval_type
    if interval_type == "none"
      # For 'none' interval type, interval_config is not required
      return
    end

    if interval_config.blank?
      errors.add(:interval_config, "cannot be blank")
      return
    end

    case interval_type
    when "weekly"
      days = interval_config["days"]
      if days.blank? || !days.is_a?(Array) || days.empty?
        errors.add(:interval_config, "must include at least one day of the week for weekly interval")
      elsif !days.all? { |day| %w[monday tuesday wednesday thursday friday saturday sunday].include?(day) }
        errors.add(:interval_config, "must include valid days of the week for weekly interval")
      end
    when "monthly"
      day = interval_config["day_of_month"]&.to_i
      unless day && day >= 1 && day <= 31
        errors.add(:interval_config, "must include valid day of month (1-31) for monthly interval")
      end
    end
  end
end
