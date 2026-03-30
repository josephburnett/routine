class SectionsController < ApplicationController
  include NamespaceBrowsing

  before_action :require_login
  before_action :find_section, only: [ :show, :edit, :update, :soft_delete, :remove_question, :move_question_up, :move_question_down, :sort_questions ]

  def index
    setup_namespace_browsing(Section, :sections_path)
    @items = apply_index_sort(Section.items_in_namespace(current_user, @current_namespace).not_deleted)
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
        FormSection.create!(form: @form, section: @section, position: FormSection.next_position_for(form_id: @form.id))
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

    if SectionQuestion.exists?(section: @section, question: @question)
      redirect_to @section, alert: "Question is already in this section"
    else
      SectionQuestion.create!(section: @section, question: @question, position: SectionQuestion.next_position_for(section_id: @section.id))
      redirect_to @section, notice: "Question added to section successfully"
    end
  end

  def remove_question
    @question = current_user.questions.find(params[:question_id])

    join = SectionQuestion.find_by(section: @section, question: @question)
    if join
      join.destroy
      redirect_to edit_section_path(@section), notice: "Question removed from section successfully"
    else
      redirect_to edit_section_path(@section), alert: "Question is not in this section"
    end
  end

  def move_question_up
    join = SectionQuestion.find_by!(section: @section, question_id: params[:question_id])
    join.move_higher!
    redirect_to @section
  end

  def move_question_down
    join = SectionQuestion.find_by!(section: @section, question_id: params[:question_id])
    join.move_lower!
    redirect_to @section
  end

  def sort_questions
    SectionQuestion.apply_sort!({ section_id: @section.id }, :question, params[:sort_by], params[:direction])
    redirect_to @section
  end

  private

  def find_section
    @section = current_user.sections.not_deleted.find(params[:id])
  end

  def section_params
    params.require(:section).permit(:name, :prompt, :namespace)
  end
end
