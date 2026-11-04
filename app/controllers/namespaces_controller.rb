class NamespacesController < ApplicationController
  before_action :require_login
  before_action :find_namespace, only: [ :show ]

  def index
    # Redirect to root namespace view
    redirect_to namespace_path("root")
  end

  def show
    if request.post?
      # Handle bulk move with cascading
      Rails.logger.info "Bulk move params: #{params.inspect}"
      target_namespace = params[:target_namespace] || ""
      entity_params = params[:entities] || {}
      skip_cascade = params[:skip_cascade] == "1"

      Rails.logger.info "Target namespace: #{target_namespace.inspect}"
      Rails.logger.info "Entity params: #{entity_params.inspect}"
      Rails.logger.info "Skip cascade: #{skip_cascade}"

      moved_count = NamespaceMove.call(
        user: current_user,
        entities: entity_params.respond_to?(:to_unsafe_h) ? entity_params.to_unsafe_h : entity_params,
        target_namespace: target_namespace,
        cascade: !skip_cascade
      )

      Rails.logger.info "Total moved count: #{moved_count}"

      if moved_count > 0
        target_display = target_namespace.present? ? target_namespace : "Root"
        # Redirect to target namespace so user can see their moved items
        target_path = target_namespace.present? ? namespace_path(target_namespace) : namespace_path("root")
        redirect_to target_path, notice: "Successfully moved #{moved_count} #{'item'.pluralize(moved_count)} to #{target_display}"
      else
        redirect_to namespace_path(@namespace), alert: "No items were selected for moving"
      end
    else
      # GET request - show the namespace with child namespaces and bulk move form
    end
  end

  private

  def find_namespace
    namespace_name = params[:id] == "root" ? "" : params[:id]
    @namespace = Namespace.find_for_user(current_user, namespace_name)
  end
end
