class MetricsController < ApplicationController
  include NamespaceBrowsing

  before_action :require_login
  before_action :find_metric, only: [ :show, :edit, :update, :soft_delete, :refresh_cache ]

  def index
    setup_namespace_browsing(Metric, :metrics_path)
    @items = apply_index_sort(Metric.items_in_namespace(current_user, @current_namespace).not_deleted)
  end

  def show
    @series_data = @metric.display_series
  end

  def new
    @metric = Metric.new
    current_ns = params[:namespace] || ""
    @questions = entities_in_allowed_namespaces(Question, current_ns)
    @metrics = entities_in_allowed_namespaces(Metric, current_ns)
  end

  def create
    @metric = current_user.metrics.build(metric_params)

    if @metric.save
      redirect_to @metric, notice: "Metric created successfully"
    else
      current_ns = @metric.namespace || ""
      @questions = entities_in_allowed_namespaces(Question, current_ns)
      @metrics = entities_in_allowed_namespaces(Metric, current_ns)
      render :new
    end
  end

  def edit
    @questions = entities_in_allowed_namespaces(Question, @metric.namespace)
    @metrics = entities_in_allowed_namespaces(Metric, @metric.namespace).where.not(id: @metric.id)
  end

  def update
    if @metric.update(metric_params)
      redirect_to @metric, notice: "Metric updated successfully"
    else
      @questions = entities_in_allowed_namespaces(Question, @metric.namespace)
      @metrics = entities_in_allowed_namespaces(Metric, @metric.namespace).where.not(id: @metric.id)
      render :edit
    end
  end

  def soft_delete
    @metric.soft_delete!
    redirect_to metrics_path, notice: "Metric deleted successfully"
  end

  def refresh_cache
    @metric.refresh_cache!
    redirect_to @metric, notice: "Cache refreshed successfully"
  end

  private

  def find_metric
    @metric = current_user.metrics.not_deleted.includes(:questions, :child_metric_metrics, :parent_metrics, :first_metric).find(params[:id])
  end

  def metric_params
    params.require(:metric).permit(:name, :function, :resolution, :width, :wrap, :scale, :first_metric_id, :namespace, :fill, question_ids: [], child_metric_ids: [])
  end
end
