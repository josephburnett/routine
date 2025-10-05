class QuestionsController < ApplicationController
  include NamespaceBrowsing
  before_action :require_login
  before_action :find_question, only: [ :show, :edit, :update, :soft_delete, :answer, :submit_answer ]

  def index
    setup_namespace_browsing(Question, :questions_path)
    @items = Question.items_in_namespace(current_user, @current_namespace).not_deleted
  end

  def show
  end

  def new
    @question = Question.new
  end

  def edit
  end

  def update
    if @question.update(question_params)
      redirect_to @question, notice: "Question updated successfully"
    else
      render :edit
    end
  end

  def soft_delete
    @question.soft_delete!
    redirect_to questions_path, notice: "Question deleted successfully"
  end

  def answer
    @answer = Answer.new
  end

  def submit_answer
    @answer = Answer.new(
      question: @question,
      user: current_user,
      answer_type: @question.question_type,
      namespace: @question.namespace
    )

    # Set the appropriate value based on question type
    case @question.question_type
    when "string"
      @answer.string_value = params[:answer_value]
    when "number"
      @answer.number_value = params[:answer_value].to_f
    when "bool"
      @answer.bool_value = params[:answer_value] == "1"
    when "range"
      @answer.number_value = params[:answer_value].to_f
    end

    if @answer.save
      redirect_to questions_path(namespace: @question.namespace), notice: "Answer submitted successfully"
    else
      render :answer, alert: "Error submitting answer"
    end
  end

  def create
    if params[:section_id]
      # Creating question from section - inherit section's namespace
      @section = current_user.sections.find(params[:section_id])
      @question = Question.new(question_params)
      @question.user = current_user
      @question.namespace = @section.namespace

      if @question.save
        @section.questions << @question
        redirect_to @section, notice: "Question created successfully"
      else
        redirect_to @section, alert: "Error creating question"
      end
    else
      # Standalone question creation
      @question = current_user.questions.build(question_params)

      if @question.save
        redirect_to @question, notice: "Question created successfully"
      else
        render :new
      end
    end
  end

  private

  def find_question
    @question = current_user.questions.not_deleted.find(params[:id])
  end

  def question_params
    params.require(:question).permit(:name, :question_type, :range_min, :range_max, :namespace)
  end
end
