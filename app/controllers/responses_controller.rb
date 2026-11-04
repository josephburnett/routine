class ResponsesController < ApplicationController
  include NamespaceBrowsing
  before_action :require_login
  before_action :find_response, only: [ :show, :edit, :update, :soft_delete ]

  def index
    if params[:form_id]
      @form = current_user.forms.find(params[:form_id])
      @responses = @form.responses.not_deleted
                        .where(user: current_user)
                        .order(created_at: :desc)
                        .page(params[:page])
                        .per(25)
      @folders = []
      @items = []
      @breadcrumbs = []
    else
      setup_namespace_browsing(Response, :responses_path)
      @items = apply_index_sort(Response.items_in_namespace(current_user, @current_namespace)
                      .not_deleted, default_sort: "created_at", default_dir: "desc")
                      .page(params[:page])
                      .per(25)
    end
  end

  def show
  end

  def new
    @response = Response.new
    @forms = current_user.forms.not_deleted
  end

  def create
    @response = current_user.responses.build(response_params)

    if @response.save
      redirect_to @response, notice: "Response created successfully"
    else
      @forms = current_user.forms.not_deleted
      render :new
    end
  end

  def edit
    @forms = current_user.forms.not_deleted
    @questions = @response.form.sections.joins(:questions).includes(:questions).flat_map(&:questions)
  end

  def update
    answers = response_params[:answers_attributes]&.to_h&.values || []
    begin
      ResponseUpdate.call(response: @response, answers: answers, datetime: params[:response][:response_datetime])
    rescue ResponseUpdate::InvalidDatetime => e
      Rails.logger.warn e.message
      flash[:alert] = "Invalid date format. Please use a valid date and time."
    rescue ActiveRecord::RecordNotFound
      raise
    rescue StandardError => e
      Rails.logger.error "Failed to update response: #{e.message}"
      flash[:alert] = "Failed to update response date and time. Please try again."
    end

    # Handle other response attributes
    response_attrs = response_params.except(:answers_attributes, :response_datetime)
    if response_attrs.present? && @response.update(response_attrs)
      redirect_to @response, notice: "Response updated successfully"
    elsif response_attrs.blank?
      redirect_to @response, notice: "Response updated successfully"
    else
      @forms = current_user.forms.not_deleted
      @questions = @response.form.sections.joins(:questions).includes(:questions).flat_map(&:questions)
      render :edit
    end
  end

  def soft_delete
    @response.soft_delete!
    redirect_to responses_path, notice: "Response deleted successfully"
  end

  private

  def find_response
    @response = current_user.responses.not_deleted.find(params[:id])
  end

  def response_params
    params.require(:response).permit(:form_id, :namespace, :response_datetime,
                                     answers_attributes: [ :id, :answer_type, :string_value, :number_value, :bool_value, :_destroy ])
  end
end
