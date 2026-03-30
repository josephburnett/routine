module NamespaceBrowsing
  extend ActiveSupport::Concern

  ALLOWED_SORT_COLUMNS = %w[name description created_at updated_at].freeze
  ALLOWED_SORT_DIRECTIONS = %w[asc desc].freeze

  def setup_namespace_browsing(model_class, path_helper)
    @current_namespace = params[:namespace] || ""
    # Use ALL namespaces, not just those specific to this entity type
    @folders = Namespace.namespace_folders_for_user(current_user, @current_namespace)
    @breadcrumbs = build_namespace_breadcrumbs(@current_namespace, path_helper)
    @current_sort = params[:sort]
    @current_dir = params[:dir]
  end

  def apply_index_sort(items, default_sort: nil, default_dir: "asc")
    sort_col = ALLOWED_SORT_COLUMNS.include?(params[:sort]) ? params[:sort] : default_sort
    return items unless sort_col

    # Check the model actually has this column
    return items unless items.model.column_names.include?(sort_col)

    direction = ALLOWED_SORT_DIRECTIONS.include?(params[:dir]) ? params[:dir] : default_dir
    items.reorder(sort_col => direction)
  end

  private

  def build_namespace_breadcrumbs(current_namespace, path_helper)
    return [ [ "Root", send(path_helper) ] ] if current_namespace.blank?

    breadcrumbs = [ [ "Root", send(path_helper) ] ]
    parts = current_namespace.split(".")

    parts.each_with_index do |part, index|
      namespace_path = parts[0..index].join(".")
      breadcrumbs << [ part, send(path_helper, namespace: namespace_path) ]
    end

    breadcrumbs
  end
end
