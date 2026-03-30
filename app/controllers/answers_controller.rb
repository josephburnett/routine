class AnswersController < ApplicationController
  include NamespaceBrowsing
  before_action :require_login
  before_action :find_answer, only: [ :show, :edit, :update, :soft_delete ]

  def index
    setup_namespace_browsing(Answer, :answers_path)
    @items = apply_index_sort(Answer.items_in_namespace(current_user, @current_namespace)
                   .not_deleted, default_sort: "created_at", default_dir: "desc")
                   .page(params[:page])
                   .per(25)
  end

  def show
  end

  def new
    @answer = Answer.new
    @questions = current_user.questions.not_deleted
  end

  def create
    @answer = current_user.answers.build(answer_params)

    if @answer.save
      redirect_to @answer, notice: "Answer created successfully"
    else
      @questions = current_user.questions.not_deleted
      render :new
    end
  end

  def edit
    @questions = current_user.questions.not_deleted
  end

  def update
    if @answer.update(answer_params)
      redirect_to @answer, notice: "Answer updated successfully"
    else
      @questions = current_user.questions.not_deleted
      render :edit
    end
  end

  def soft_delete
    @answer.soft_delete!
    redirect_to answers_path, notice: "Answer deleted successfully"
  end

  private

  def find_answer
    @answer = current_user.answers.not_deleted.find(params[:id])
  end

  def answer_params
    params.require(:answer).permit(:question_id, :answer_type, :string_value, :number_value, :bool_value, :namespace)
  end
end
