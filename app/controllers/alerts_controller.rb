class AlertsController < ApplicationController
  include NamespaceBrowsing

  before_action :require_login
  before_action :find_alert, only: [ :show, :edit, :update, :soft_delete ]

  def index
    setup_namespace_browsing(Alert, :alerts_path)
    @items = Alert.items_in_namespace(current_user, @current_namespace).not_deleted.includes(:metric)
  end

  def show
    # Cache the expensive series calculation to avoid multiple calls
    begin
      @metric_series = @alert.metric.series  # Use full series like alert calculation
      @has_series_data = @metric_series.any?
      @latest_value = @metric_series.last&.last
    rescue => e
      Rails.logger.warn "Alert #{@alert.id} series calculation failed: #{e.message}"
      @metric_series = []
      @has_series_data = false
      @latest_value = nil
    end
  end

  def new
    @alert = Alert.new
    current_ns = params[:namespace] || ""
    @metrics = entities_in_allowed_namespaces(Metric, current_ns)
  end

  def create
    @alert = current_user.alerts.build(alert_params)

    if @alert.save
      redirect_to @alert, notice: "Alert created successfully"
    else
      current_ns = @alert.namespace || ""
      @metrics = entities_in_allowed_namespaces(Metric, current_ns)
      render :new
    end
  end

  def edit
    @metrics = entities_in_allowed_namespaces(Metric, @alert.namespace)
  end

  def update
    if @alert.update(alert_params)
      redirect_to @alert, notice: "Alert updated successfully"
    else
      @metrics = entities_in_allowed_namespaces(Metric, @alert.namespace)
      render :edit
    end
  end

  def soft_delete
    @alert.soft_delete!
    redirect_to alerts_path, notice: "Alert deleted successfully"
  end

  private

  def find_alert
    @alert = current_user.alerts.not_deleted.includes(metric: [ :questions, :child_metric_metrics ]).find(params[:id])
  end

  def alert_params
    params.require(:alert).permit(:name, :metric_id, :threshold, :direction, :namespace, :delay, :message)
  end
end
