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
      @items = Response.items_in_namespace(current_user, @current_namespace)
                      .not_deleted
                      .order(created_at: :desc)
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
    # Handle answer updates
    if params[:response][:answers_attributes]
      params[:response][:answers_attributes].each do |index, answer_params|
        next if answer_params[:_destroy] == "1"

        answer = @response.answers.find(answer_params[:id])
        answer.update!(answer_params.except(:id))
      end
    end

    # Handle datetime update if provided
    if params[:response][:response_datetime].present?
      begin
        new_datetime = Time.zone.parse(params[:response][:response_datetime])
        @response.update_timestamp!(new_datetime) if new_datetime
      rescue ArgumentError => e
        Rails.logger.warn "Invalid datetime format: #{params[:response][:response_datetime]} - #{e.message}"
        flash[:alert] = "Invalid date format. Please use a valid date and time."
      rescue StandardError => e
        Rails.logger.error "Failed to update response timestamp: #{e.message}"
        flash[:alert] = "Failed to update response date and time. Please try again."
      end
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
