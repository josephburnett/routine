# Report schedule and contents, shared by the report pages and MCP tools.
module ReportConfig
  module_function

  # Sets report.interval_config from the submitted schedule.
  # raw: { "days" => [...] } for weekly, { "day_of_month" => n } for monthly.
  # nil clears it. Other interval types leave it unchanged.
  def apply_interval_config(report, interval_type, raw)
    if raw.blank?
      report.interval_config = {}
      return
    end

    raw = raw.to_h.stringify_keys
    case interval_type
    when "weekly"
      report.interval_config = { "days" => Array(raw["days"]).reject(&:blank?) }
    when "monthly"
      report.interval_config = raw["day_of_month"].present? ? { "day_of_month" => raw["day_of_month"].to_i } : {}
    end
  end

  # Replaces the report's alerts and metrics, in the given order. Only the
  # user's own alerts and metrics are linked; nil leaves that list unchanged.
  def replace_contents(report, user:, alert_ids: nil, metric_ids: nil)
    unless alert_ids.nil?
      report.report_alerts.destroy_all
      owned_ids(user.alerts, alert_ids).each_with_index do |id, idx|
        report.report_alerts.create(alert_id: id, position: idx)
      end
    end

    unless metric_ids.nil?
      report.report_metrics.destroy_all
      owned_ids(user.metrics, metric_ids).each_with_index do |id, idx|
        report.report_metrics.create(metric_id: id, position: idx)
      end
    end
  end

  # Emails the report now. Returns [ok, message].
  def send_now(report)
    return [ false, "Cannot send report: no content to send (no active alerts or metrics)" ] unless report.has_content_to_send?

    ReportMailer.scheduled_report(report).deliver_now
    report.update!(last_sent_at: Time.current)
    [ true, "Report sent successfully! Check your email." ]
  rescue => e
    Rails.logger.error "Failed to send report #{report.name} (ID: #{report.id}): #{e.message}"
    [ false, "Failed to send report: #{e.message}" ]
  end

  def owned_ids(scope, ids)
    wanted = Array(ids).reject(&:blank?).map(&:to_i)
    owned = scope.where(id: wanted).pluck(:id).to_set
    wanted.select { |id| owned.include?(id) }
  end
end
