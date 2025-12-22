class RemembersController < ApplicationController
  include NamespaceBrowsing

  before_action :require_login
  before_action :find_remember, only: [ :show, :edit, :update, :soft_delete, :pin, :float, :bump_up, :bump_down, :retire, :set_decay ]

  def index
    setup_namespace_browsing(Remember, :remembers_path)
    # Show ALL remembers in current namespace (including retired) in decay order
    @items = Remember.items_in_namespace(current_user, @current_namespace)
                     .not_deleted
                     .sorted_by_decay
  end

  # Streamlined view showing only visible_today remembers
  # Includes current namespace and all child namespaces
  def display
    @current_namespace = params[:namespace] || ""
    @items = Remember.visible_today_recursive(current_user, @current_namespace)
  end

  def show
  end

  def new
    @remember = Remember.new
  end

  def create
    @remember = current_user.remembers.build(remember_params)

    if @remember.save
      redirect_to remembers_path(namespace: @remember.namespace), notice: "Remember created successfully"
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @remember.update(remember_params)
      redirect_to @remember, notice: "Remember updated successfully"
    else
      render :edit
    end
  end

  def soft_delete
    @remember.soft_delete!
    redirect_to remembers_path(namespace: @remember.namespace), notice: "Remember deleted successfully"
  end

  def pin
    @remember.pin!
    redirect_back_to_list("Remember pinned (decay: #{format('%.2f', @remember.decay)})")
  end

  def float
    @remember.float!
    redirect_back_to_list("Remember floating (decay: #{format('%.2f', @remember.decay)})")
  end

  def set_decay
    min_decay = current_user.user_setting&.remember_min_decay || 0.01
    decay_value = params[:decay].to_f.clamp(min_decay, 1.0)
    @remember.set_decay!(decay_value)
    redirect_to @remember, notice: "Decay set to #{format('%.2f', decay_value)} and pinned"
  end

  def bump_up
    @remember.bump_up!
    redirect_back_to_list("Remember bumped up (decay: #{format('%.2f', @remember.decay)})")
  end

  def bump_down
    @remember.bump_down!
    redirect_back_to_list("Remember bumped down (decay: #{format('%.2f', @remember.decay)})")
  end

  def retire
    @remember.retire!
    redirect_back_to_list("Remember retired")
  end

  private

  def find_remember
    @remember = current_user.remembers.not_deleted.find(params[:id])
  end

  def remember_params
    params.require(:remember).permit(:description, :background, :namespace)
  end

  def redirect_back_to_list(notice_message)
    if params[:return_to] == "display"
      redirect_to display_remembers_path(namespace: params[:display_namespace]), notice: notice_message
    else
      redirect_to remembers_path(namespace: @remember.namespace), notice: notice_message
    end
  end
end
