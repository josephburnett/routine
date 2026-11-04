class FormsController < ApplicationController
  include NamespaceBrowsing

  before_action :require_login
  before_action :find_form, only: [ :show, :edit, :update, :soft_delete, :survey, :submit_survey, :update_draft, :remove_section, :move_section_up, :move_section_down, :sort_sections ]

  def index
    setup_namespace_browsing(Form, :forms_path)
    @items = apply_index_sort(Form.items_in_namespace(current_user, @current_namespace).not_deleted)
  end

  def show
    @section = Section.new
    @available_sections = current_user.sections.not_deleted - @form.sections
  end

  def new
    @form = Form.new
  end

  def create
    @form = current_user.forms.build(form_params)

    if @form.save
      redirect_to @form, notice: "Form created successfully"
    else
      render :new
    end
  end

  def edit
  end

  def update
    Rails.logger.info "Form params: #{form_params.inspect}"
    if @form.update(form_params)
      Rails.logger.info "Form updated successfully. New namespace: #{@form.namespace.inspect}"
      redirect_to @form, notice: "Form updated successfully"
    else
      Rails.logger.error "Form update failed: #{@form.errors.full_messages}"
      render :edit
    end
  end

  def soft_delete
    @form.soft_delete!
    redirect_to forms_path, notice: "Form deleted successfully"
  end

  def survey
    @response = Response.new
    @draft = FormDraft.find_or_initialize_by(user: current_user, form: @form)
  end

  def submit_survey
    answers = (params[:answers]&.to_unsafe_h || {}).transform_values { |data| data["value"] }
    if SurveySubmission.call(form: @form, user: current_user, answers: answers)
      redirect_to @form, notice: "Form submitted successfully"
    else
      @response = Response.new
      @draft = FormDraft.find_or_initialize_by(user: current_user, form: @form)
      render :survey, alert: "Error submitting form"
    end
  end

  def update_draft
    draft = FormDraft.find_or_initialize_by(user: current_user, form: @form)
    draft.draft_data ||= {}
    draft.draft_data[params[:field_id]] = params[:value]

    if draft.save
      render json: { status: "success" }
    else
      render json: { status: "error" }
    end
  end

  def add_section
    @form = current_user.forms.find(params[:id])
    @section = current_user.sections.find(params[:section_id])

    if Membership.add(:form_sections, @form, @section)
      redirect_to @form, notice: "Section added to form successfully"
    else
      redirect_to @form, alert: "Section is already in this form"
    end
  end

  def remove_section
    @section = current_user.sections.find(params[:section_id])

    if Membership.remove(:form_sections, @form, @section)
      redirect_to edit_form_path(@form), notice: "Section removed from form successfully"
    else
      redirect_to edit_form_path(@form), alert: "Section is not in this form"
    end
  end

  def move_section_up
    move_or_404(:form_sections, @form, params[:section_id], :up)
    redirect_to @form
  end

  def move_section_down
    move_or_404(:form_sections, @form, params[:section_id], :down)
    redirect_to @form
  end

  def sort_sections
    Membership.sort(:form_sections, @form, params[:sort_by], params[:direction])
    redirect_to @form
  end

  private

  def find_form
    @form = current_user.forms.not_deleted.find(params[:id])
  end

  def form_params
    params.require(:form).permit(:name, :namespace)
  end
end
