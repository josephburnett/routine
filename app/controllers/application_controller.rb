class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  include ApplicationHelper

  private

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end

  def logged_in?
    !!current_user
  end

  def require_login
    unless logged_in?
      redirect_to login_path, alert: "Please log in to continue"
    end
  end

  # Moves a linked child up or down; 404 if it isn't linked to the parent.
  def move_or_404(relation, parent, child_id, direction)
    Membership.move(relation, parent, child_id, direction)
  rescue Membership::Error
    raise ActiveRecord::RecordNotFound
  end

  helper_method :current_user, :logged_in?
end
