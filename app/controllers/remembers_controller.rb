class RemembersController < ApplicationController
  include NamespaceBrowsing

  before_action :require_login
  before_action :find_remember, only: [ :show, :edit, :update, :soft_delete, :pin, :bump_up, :bump_down, :retire ]

  def index
    setup_namespace_browsing(Remember, :remembers_path)
    @show_retired = params[:show_retired] == "true"

    if @show_retired
      # Show all non-deleted remembers including retired
      @items = Remember.items_in_namespace(current_user, @current_namespace)
                       .not_deleted
                       .sorted_by_visibility
    else
      # Show only visible remembers for today
      @items = Remember.visible_today_for_user(current_user, @current_namespace)
    end
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
    redirect_to remembers_path(namespace: @remember.namespace, show_retired: params[:show_retired]),
                notice: "Remember pinned"
  end

  def bump_up
    @remember.bump_up!
    redirect_to remembers_path(namespace: @remember.namespace, show_retired: params[:show_retired]),
                notice: "Remember bumped up (decay: #{format('%.2f', @remember.decay)})"
  end

  def bump_down
    @remember.bump_down!
    redirect_to remembers_path(namespace: @remember.namespace, show_retired: params[:show_retired]),
                notice: "Remember bumped down (decay: #{format('%.2f', @remember.decay)})"
  end

  def retire
    @remember.retire!
    redirect_to remembers_path(namespace: @remember.namespace, show_retired: params[:show_retired]),
                notice: "Remember retired"
  end

  private

  def find_remember
    @remember = current_user.remembers.not_deleted.find(params[:id])
  end

  def remember_params
    params.require(:remember).permit(:description, :background, :namespace)
  end
end
