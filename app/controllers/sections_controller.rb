class SectionsController < ApplicationController
  include NamespaceBrowsing

  before_action :require_login
  before_action :find_section, only: [ :show, :edit, :update, :soft_delete, :remove_question ]

  def index
    setup_namespace_browsing(Section, :sections_path)
    @items = Section.items_in_namespace(current_user, @current_namespace).not_deleted
  end

  def show
    @question = Question.new
    @available_questions = (current_user.questions.not_deleted - @section.questions)
      .sort_by { |q| [ q.namespace.to_s, q.name.to_s ] }
  end

  def new
    @section = Section.new
  end

  def create
    if params[:form_id]
      # Creating section from form - inherit form's namespace
      @form = current_user.forms.find(params[:form_id])
      @section = Section.new(section_params)
      @section.user = current_user
      @section.namespace = @form.namespace

      if @section.save
        @form.sections << @section
        redirect_to @form, notice: "Section created successfully"
      else
        redirect_to @form, alert: "Error creating section"
      end
    else
      # Standalone section creation
      @section = current_user.sections.build(section_params)

      if @section.save
        redirect_to @section, notice: "Section created successfully"
      else
        render :new
      end
    end
  end

  def edit
  end

  def update
    if @section.update(section_params)
      redirect_to @section, notice: "Section updated successfully"
    else
      render :edit
    end
  end

  def soft_delete
    @section.soft_delete!
    redirect_to sections_path, notice: "Section deleted successfully"
  end


  def add_question
    @section = current_user.sections.find(params[:id])
    @question = current_user.questions.find(params[:question_id])

    unless @section.questions.include?(@question)
      @section.questions << @question
      redirect_to @section, notice: "Question added to section successfully"
    else
      redirect_to @section, alert: "Question is already in this section"
    end
  end

  def remove_question
    @question = current_user.questions.find(params[:question_id])

    if @section.questions.include?(@question)
      @section.questions.delete(@question)
      redirect_to edit_section_path(@section), notice: "Question removed from section successfully"
    else
      redirect_to edit_section_path(@section), alert: "Question is not in this section"
    end
  end

  private

  def find_section
    @section = current_user.sections.not_deleted.find(params[:id])
  end

  def section_params
    params.require(:section).permit(:name, :prompt, :namespace)
  end
end
