module ApplicationHelper
  def all_namespaces_for_user(user)
    namespaces = Set.new

    # Collect all possible namespaces from all namespaceable models
    [ Form, Section, Question, Answer, Response, Metric, Alert, Dashboard ].each do |model|
      namespaces.merge(model.namespaces_for_user(user))
    end

    # Filter out namespaces that don't actually have any entities
    active_namespaces = namespaces.select do |namespace|
      [ Form, Section, Question, Answer, Response, Metric, Alert, Dashboard ].any? do |model|
        model.where(user: user, namespace: namespace).exists?
      end
    end

    active_namespaces.sort
  end

  def current_namespace
    # Try to get namespace from various sources in order of preference
    if instance_variable_defined?("@current_namespace")
      @current_namespace
    elsif instance_variable_defined?("@form") && @form
      @form.namespace
    elsif instance_variable_defined?("@section") && @section
      @section.namespace
    elsif instance_variable_defined?("@question") && @question
      @question.namespace
    elsif instance_variable_defined?("@answer") && @answer
      @answer.namespace
    elsif instance_variable_defined?("@response") && @response
      @response.namespace
    elsif instance_variable_defined?("@metric") && @metric
      @metric.namespace
    elsif instance_variable_defined?("@alert") && @alert
      @alert.namespace
    elsif instance_variable_defined?("@dashboard") && @dashboard
      @dashboard.namespace
    elsif instance_variable_defined?("@namespace") && @namespace
      @namespace.name
    elsif params[:namespace]
      params[:namespace]
    else
      ""
    end
  end

  def namespace_aware_path(model_class, path_method)
    namespace = current_namespace || ""

    # Always stay in current namespace if one is active
    # This allows entering empty namespaces and creating the first entity of any type
    if namespace.present?
      send(path_method, namespace: namespace)
    else
      # Only fall back to root if we're already in root
      send(path_method)
    end
  end

  def namespace_aware_namespaces_path
    namespace = current_namespace || ""

    if namespace.present?
      namespace_path(namespace)
    else
      namespaces_path
    end
  end

  def namespace_aware_settings_path
    namespace = current_namespace || ""

    if namespace.present?
      settings_path(return_namespace: namespace)
    else
      settings_path
    end
  end

  def allowed_namespaces_for_selection(current_namespace)
    # Root can access everything
    return all_namespaces_for_user(current_user) if current_namespace.blank?

    # Current namespace + all child namespaces
    all_namespaces = all_namespaces_for_user(current_user)

    # Include current namespace
    allowed = [ current_namespace ]

    # Include all child namespaces (those that start with current namespace + ".")
    child_namespaces = all_namespaces.select do |namespace|
      namespace.start_with?("#{current_namespace}.")
    end

    allowed + child_namespaces
  end

  def entities_in_allowed_namespaces(model_class, current_namespace)
    allowed_namespaces = allowed_namespaces_for_selection(current_namespace)
    model_class.where(user: current_user, namespace: allowed_namespaces).not_deleted
  end
end
