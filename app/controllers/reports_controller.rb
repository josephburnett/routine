class ReportsController < ApplicationController
  include NamespaceBrowsing

  before_action :require_login
  before_action :find_report, only: [ :edit, :update, :soft_delete, :send_now, :move_alert_up, :move_alert_down, :sort_alerts, :move_metric_up, :move_metric_down, :sort_metrics ]

  def index
    setup_namespace_browsing(Report, :reports_path)
    @items = apply_index_sort(Report.items_in_namespace(current_user, @current_namespace).not_deleted.includes(:alerts, :metrics))
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

    # Load visible Remembers if remember_namespace is set (nil = None, "" = Root, "namespace" = specific namespace)
    if @report.remember_namespace.nil?
      # nil means "None" - don't show Remembers
      @visible_remembers = []
    else
      # Empty string ("") means Root namespace, otherwise use the specified namespace
      @visible_remembers = Remember.visible_today_recursive(current_user, @report.remember_namespace)
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

    ReportConfig.apply_interval_config(@report, params.dig(:report, :interval_type), submitted_interval_config)

    if @report.save
      ReportConfig.replace_contents(@report, user: current_user,
                                    alert_ids: params[:alert_ids] || [], metric_ids: params[:metric_ids] || [])

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
    ReportConfig.apply_interval_config(@report, params.dig(:report, :interval_type), submitted_interval_config)

    if @report.update(report_params)
      ReportConfig.replace_contents(@report, user: current_user,
                                    alert_ids: params[:alert_ids] || [], metric_ids: params[:metric_ids] || [])

      redirect_to @report, notice: "Report updated successfully"
    else
      @alerts = entities_in_allowed_namespaces(Alert, @report.namespace)
      @metrics = entities_in_allowed_namespaces(Metric, @report.namespace)
      render :edit, status: :unprocessable_entity
    end
  end

  def send_now
    ok, message = ReportConfig.send_now(@report)
    redirect_to @report, (ok ? :notice : :alert) => message
  end

  def move_alert_up
    move_or_404(:report_alerts, @report, params[:alert_id], :up)
    redirect_to @report
  end

  def move_alert_down
    move_or_404(:report_alerts, @report, params[:alert_id], :down)
    redirect_to @report
  end

  def sort_alerts
    Membership.sort(:report_alerts, @report, params[:sort_by], params[:direction])
    redirect_to @report
  end

  def move_metric_up
    move_or_404(:report_metrics, @report, params[:metric_id], :up)
    redirect_to @report
  end

  def move_metric_down
    move_or_404(:report_metrics, @report, params[:metric_id], :down)
    redirect_to @report
  end

  def sort_metrics
    Membership.sort(:report_metrics, @report, params[:sort_by], params[:direction])
    redirect_to @report
  end

  def soft_delete
    @report.soft_delete!
    redirect_to reports_path, notice: "Report deleted successfully"
  end

  private

  def find_report
    @report = current_user.reports.not_deleted.find(params[:id])
  end

  def submitted_interval_config
    params[:interval_config].present? ? params[:interval_config].to_unsafe_h : nil
  end

  def report_params
    params.require(:report).permit(:name, :time_of_day, :interval_type, :namespace, :remember_namespace, interval_config: {})
  end
end
