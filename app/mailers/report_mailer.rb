class ReportMailer < ApplicationMailer
  default from: "routine@#{ENV.fetch('APPLICATION_HOST', 'home.local')}"

  def scheduled_report(report)
    @report = report
    @user = report.user
    @active_alerts = report.active_alerts
    @metrics = report.metrics

    # Generate metric summaries
    @metric_summaries = @metrics.map do |metric|
      series_data = metric.series || []
      {
        metric: metric,
        latest_value: series_data.last&.last,
        data_points: series_data.count,
        time_range: series_data.any? ? "#{series_data.first.first.strftime('%b %d')} - #{series_data.last.first.strftime('%b %d')}" : "No data"
      }
    end

    mail(
      to: @user.email,
      subject: "Routine Report: #{@report.name}"
    )
  end
end
