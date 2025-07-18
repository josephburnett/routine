class MetricsController < ApplicationController
  include NamespaceBrowsing

  before_action :require_login
  before_action :find_metric, only: [ :show, :edit, :update, :soft_delete, :refresh_cache ]

  def index
    setup_namespace_browsing(Metric, :metrics_path)
    @items = Metric.items_in_namespace(current_user, @current_namespace).not_deleted
  end

  def show
    @series_data = limit_series_data(@metric.series)
  end

  def new
    @metric = Metric.new
    current_ns = params[:namespace] || ""
    @questions = entities_in_allowed_namespaces(Question, current_ns)
    @metrics = entities_in_allowed_namespaces(Metric, current_ns).enabled
  end

  def create
    @metric = current_user.metrics.build(metric_params)

    if @metric.save
      redirect_to @metric, notice: "Metric created successfully"
    else
      current_ns = @metric.namespace || ""
      @questions = entities_in_allowed_namespaces(Question, current_ns)
      @metrics = entities_in_allowed_namespaces(Metric, current_ns).enabled
      render :new
    end
  end

  def edit
    @questions = entities_in_allowed_namespaces(Question, @metric.namespace)
    @metrics = entities_in_allowed_namespaces(Metric, @metric.namespace).where.not(id: @metric.id).enabled
  end

  def update
    if @metric.update(metric_params)
      redirect_to @metric, notice: "Metric updated successfully"
    else
      @questions = entities_in_allowed_namespaces(Question, @metric.namespace)
      @metrics = entities_in_allowed_namespaces(Metric, @metric.namespace).where.not(id: @metric.id).enabled
      render :edit
    end
  end

  def soft_delete
    @metric.soft_delete!
    redirect_to metrics_path, notice: "Metric deleted successfully"
  end

  def refresh_cache
    @metric.metric_series_cache&.destroy
    # Also clear alert caches for alerts using this metric
    @metric.alerts.each do |alert|
      alert.alert_status_cache&.destroy
    end
    redirect_to @metric, notice: "Cache refreshed successfully"
  end

  private

  def find_metric
    @metric = current_user.metrics.not_deleted.includes(:questions, :child_metric_metrics, :parent_metrics, :first_metric).find(params[:id])
  end

  def limit_series_data(series)
    case @metric.width
    when "daily"
      series.last((1.2 * 1).ceil)  # 1 day * 1.2 = ~2 points
    when "weekly"
      series.last((1.2 * 7).ceil)  # 7 days * 1.2 = ~9 points
    when "monthly"
      series.last((1.2 * 30).ceil)  # 30 days * 1.2 = ~36 points
    when "7_days"
      series.last((1.2 * 7).ceil)  # 7 days * 1.2 = ~9 points
    when "30_days"
      series.last((1.2 * 30).ceil)  # 30 days * 1.2 = ~36 points
    when "90_days"
      series.last((1.2 * 90).ceil)  # 90 days * 1.2 = ~108 points
    when "yearly"
      series.last((1.2 * 365).ceil)  # 365 days * 1.2 = ~438 points
    when "all_time"
      series  # Load everything for all_time, even if it takes a long time
    else
      series.last(100)  # Fallback for unknown width values
    end
  end

  def metric_params
    params.require(:metric).permit(:name, :function, :resolution, :width, :wrap, :scale, :first_metric_id, :namespace, :fill, :disabled, question_ids: [], child_metric_ids: [])
  end
end
