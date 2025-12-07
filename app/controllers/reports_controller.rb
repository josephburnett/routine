class ReportsController < ApplicationController
  include NamespaceBrowsing
  require "timeout"

  before_action :require_login
  before_action :find_report, only: [ :edit, :update, :soft_delete, :send_now ]

  def index
    setup_namespace_browsing(Report, :reports_path)
    @items = Report.items_in_namespace(current_user, @current_namespace).not_deleted.includes(:alerts, :metrics)
  end

  def show
    # Preload associations to avoid N+1 queries
    @report = current_user.reports.not_deleted
                          .includes(alerts: :metric, metrics: [])
                          .find(params[:id])

    # Basic metric information without expensive series calculations
    @metric_summaries = @report.metrics.map do |metric|
      {
        metric: metric,
        has_data: true  # Assume metrics have data - avoid expensive series calls
      }
    end

    # Basic alert information without expensive activation status calculations
    @alert_summaries = @report.alerts.map do |alert|
      {
        alert: alert,
        is_activated: nil  # Skip expensive activation check for performance
      }
    end

    # Load visible Remembers if remember_namespace is set
    if @report.remember_namespace.present?
      @visible_remembers = Remember.visible_today_recursive(current_user, @report.remember_namespace)
    else
      @visible_remembers = []
    end

    # Basic report status without expensive calculations
    @report_status = {
      has_content: @report.metrics.any? || @report.alerts.any? || @visible_remembers.any?,
      should_send: false,  # Skip expensive should_send_now check
      active_alerts_count: 0  # Skip expensive activation checks
    }
  end

  def new
    @report = Report.new
    current_ns = params[:namespace] || ""
    @alerts = entities_in_allowed_namespaces(Alert, current_ns)
    @metrics = entities_in_allowed_namespaces(Metric, current_ns)
  end

  def create
    @report = current_user.reports.build(report_params)

    # Handle interval_config processing
    if params[:interval_config].present?
      case params[:report][:interval_type]
      when "weekly"
        if params[:interval_config][:days].present?
          @report.interval_config = { "days" => params[:interval_config][:days].reject(&:blank?) }
        else
          @report.interval_config = { "days" => [] }
        end
      when "monthly"
        if params[:interval_config][:day_of_month].present?
          @report.interval_config = { "day_of_month" => params[:interval_config][:day_of_month].to_i }
        else
          @report.interval_config = {}
        end
      end
    else
      @report.interval_config = {}
    end

    if @report.save
      # Handle alert associations
      if params[:alert_ids].present?
        params[:alert_ids].each do |alert_id|
          @report.report_alerts.create(alert_id: alert_id) if alert_id.present?
        end
      end

      # Handle metric associations
      if params[:metric_ids].present?
        params[:metric_ids].each do |metric_id|
          @report.report_metrics.create(metric_id: metric_id) if metric_id.present?
        end
      end

      redirect_to @report, notice: "Report created successfully"
    else
      current_ns = @report.namespace || ""
      @alerts = entities_in_allowed_namespaces(Alert, current_ns)
      @metrics = entities_in_allowed_namespaces(Metric, current_ns)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @alerts = entities_in_allowed_namespaces(Alert, @report.namespace)
    @metrics = entities_in_allowed_namespaces(Metric, @report.namespace)
  end

  def update
    # Handle interval_config processing
    if params[:interval_config].present?
      case params[:report][:interval_type]
      when "weekly"
        if params[:interval_config][:days].present?
          @report.interval_config = { "days" => params[:interval_config][:days].reject(&:blank?) }
        else
          @report.interval_config = { "days" => [] }
        end
      when "monthly"
        if params[:interval_config][:day_of_month].present?
          @report.interval_config = { "day_of_month" => params[:interval_config][:day_of_month].to_i }
        else
          @report.interval_config = {}
        end
      end
    else
      @report.interval_config = {}
    end

    if @report.update(report_params)
      # Update alert associations
      @report.report_alerts.destroy_all
      if params[:alert_ids].present?
        params[:alert_ids].each do |alert_id|
          @report.report_alerts.create(alert_id: alert_id) if alert_id.present?
        end
      end

      # Update metric associations
      @report.report_metrics.destroy_all
      if params[:metric_ids].present?
        params[:metric_ids].each do |metric_id|
          @report.report_metrics.create(metric_id: metric_id) if metric_id.present?
        end
      end

      redirect_to @report, notice: "Report updated successfully"
    else
      @alerts = entities_in_allowed_namespaces(Alert, @report.namespace)
      @metrics = entities_in_allowed_namespaces(Metric, @report.namespace)
      render :edit, status: :unprocessable_entity
    end
  end

  def send_now
    begin
      # Check if report has content to send
      unless @report.has_content_to_send?
        redirect_to @report, alert: "Cannot send report: no content to send (no active alerts or metrics)"
        return
      end

      # Send the report
      ReportMailer.scheduled_report(@report).deliver_now
      @report.update!(last_sent_at: Time.current)

      redirect_to @report, notice: "Report sent successfully! Check your email."
    rescue => e
      Rails.logger.error "Failed to send report #{@report.name} (ID: #{@report.id}): #{e.message}"
      redirect_to @report, alert: "Failed to send report: #{e.message}"
    end
  end

  def soft_delete
    @report.soft_delete!
    redirect_to reports_path, notice: "Report deleted successfully"
  end

  private

  def find_report
    @report = current_user.reports.not_deleted.find(params[:id])
  end

  def report_params
    params.require(:report).permit(:name, :time_of_day, :interval_type, :namespace, :remember_namespace, interval_config: {})
  end

  def safe_has_content_to_send?
    # Check metrics first (fast operation)
    return true if @report.metrics.any?

    # Only check active alerts if no metrics (potentially slow operation)
    begin
      Timeout.timeout(3) { @report.active_alerts.any? }
    rescue Timeout::Error, StandardError => e
      Rails.logger.warn "Report #{@report.id} active_alerts check failed: #{e.message}"
      false
    end
  end

  def safe_should_send_now?
    Timeout.timeout(3) { @report.should_send_now? }
  rescue Timeout::Error, StandardError => e
    Rails.logger.warn "Report #{@report.id} should_send_now failed: #{e.message}"
    false
  end
end
