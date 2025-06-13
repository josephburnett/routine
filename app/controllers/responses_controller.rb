class ResponsesController < ApplicationController
  before_action :require_login
  before_action :find_response, only: [:show, :edit, :update, :soft_delete]
  
  def index
    if params[:form_id]
      @form = current_user.forms.find(params[:form_id])
      @responses = @form.responses.not_deleted.where(user: current_user)
    else
      @responses = current_user.responses.not_deleted
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
      redirect_to @response, notice: 'Response created successfully'
    else
      @forms = current_user.forms.not_deleted
      render :new
    end
  end
  
  def edit
    @forms = current_user.forms.not_deleted
  end
  
  def update
    if @response.update(response_params)
      redirect_to @response, notice: 'Response updated successfully'
    else
      @forms = current_user.forms.not_deleted
      render :edit
    end
  end
  
  def soft_delete
    @response.soft_delete!
    redirect_to responses_path, notice: 'Response deleted successfully'
  end
  
  private
  
  def find_response
    @response = current_user.responses.not_deleted.find(params[:id])
  end
  
  def response_params
    params.require(:response).permit(:form_id)
  end
end
