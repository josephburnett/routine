class Namespace
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :name, :string
  attribute :user_id, :integer

  def self.all_for_user(user)
    namespaces = Set.new

    # Collect all namespaces from all namespaceable models
    [ Form, Section, Question, Answer, Response, Metric, Alert, Remember ].each do |model|
      namespaces.merge(model.namespaces_for_user(user))
    end

    # Add intermediate namespaces (parent folders that don't have direct entities)
    # For example, if we have "house.irrigation", we also need "house" to be navigable
    intermediate_namespaces = Set.new
    namespaces.each do |namespace|
      parts = namespace.split(".")
      # Add all parent paths
      (1...parts.length).each do |i|
        parent_namespace = parts[0...i].join(".")
        intermediate_namespaces.add(parent_namespace)
      end
    end
    namespaces.merge(intermediate_namespaces)

    # Convert to Namespace objects
    namespaces.map { |name| new(name: name, user_id: user.id) }
  end

  def self.find_for_user(user, namespace_name)
    # For root namespace, always allow it
    if namespace_name.blank?
      return new(name: "", user_id: user.id)
    end

    # Check if namespace exists either by having direct entities or by having child namespaces
    all_namespaces = all_for_user(user).map(&:name)

    # Direct existence: has entities in this exact namespace
    has_direct_entities = [ Form, Section, Question, Answer, Response, Metric, Alert, Remember ].any? do |model|
      model.where(user: user, namespace: namespace_name).exists?
    end

    # Indirect existence: has child namespaces (is a valid intermediate folder)
    has_child_namespaces = all_namespaces.any? { |ns| ns.start_with?("#{namespace_name}.") }

    if has_direct_entities || has_child_namespaces
      new(name: namespace_name, user_id: user.id)
    else
      raise ActiveRecord::RecordNotFound, "Namespace '#{namespace_name}' not found"
    end
  end

  def self.namespace_folders_for_user(user, current_namespace = "")
    namespaces = all_for_user(user).map(&:name)

    # Filter namespaces that start with current_namespace
    prefix = current_namespace.present? ? "#{current_namespace}." : ""
    relevant_namespaces = namespaces.select { |ns| ns.start_with?(prefix) }

    # Get immediate child folders
    folders = Set.new
    relevant_namespaces.each do |namespace|
      # Remove the prefix to get relative path
      relative_path = namespace[prefix.length..-1]
      next if relative_path.blank?

      # Get the first component (immediate child folder)
      first_component = relative_path.split(".").first
      folders.add(first_component) if first_component.present?
    end

    folders.to_a.sort
  end

  def self.items_in_namespace(user, namespace_name = "")
    # Get namespaces that are directly in the specified namespace (not in subfolders)
    all_namespaces = all_for_user(user).map(&:name)

    # Filter to only show namespaces that are direct children of current namespace
    prefix = namespace_name.present? ? "#{namespace_name}." : ""

    direct_children = all_namespaces.select do |ns|
      # Skip if doesn't start with prefix
      next false unless ns.start_with?(prefix)

      # Remove prefix to get relative path
      relative_path = ns[prefix.length..-1]
      next false if relative_path.blank?

      # Only include if there are no more dots (direct child, not grandchild)
      !relative_path.include?(".")
    end

    direct_children.map { |name| new(name: name, user_id: user.id) }
  end

  def user
    @user ||= User.find(user_id)
  end

  def entities
    @entities ||= begin
      entities = {}
      [
        [ "Forms", Form ],
        [ "Sections", Section ],
        [ "Questions", Question ],
        [ "Answers", Answer ],
        [ "Responses", Response ],
        [ "Metrics", Metric ],
        [ "Alerts", Alert ],
        [ "Remembers", Remember ]
      ].each do |label, model|
        items = model.where(user: user, namespace: name).not_deleted
        entities[label] = items if items.any?
      end
      entities
    end
  end

  def child_namespaces
    @child_namespaces ||= begin
      all_namespaces = self.class.all_for_user(user).map(&:name)

      # Find folders that represent the first level of namespaces deeper than current
      prefix = name.present? ? "#{name}." : ""
      folders = Set.new

      all_namespaces.each do |ns|
        # Skip if doesn't start with prefix
        next unless ns.start_with?(prefix)

        # Remove prefix to get relative path
        relative_path = ns[prefix.length..-1]
        next if relative_path.blank?

        # Get the first component (immediate child folder)
        first_component = relative_path.split(".").first
        folders.add(first_component) if first_component.present?
      end

      # Convert folders to namespace objects
      folders.map do |folder|
        child_namespace_name = name.present? ? "#{name}.#{folder}" : folder
        self.class.new(name: child_namespace_name, user_id: user_id)
      end.sort_by(&:name)
    end
  end

  def total_entities_count
    entities.values.sum(&:count)
  end

  def parent_namespace
    return "" if name.blank?

    parts = name.split(".")
    return "" if parts.length <= 1

    parts[0..-2].join(".")
  end

  def folder_name
    return "Root" if name.blank?
    name.split(".").last
  end

  def to_param
    name.present? ? name : "root"
  end

  def persisted?
    false
  end

  def ==(other)
    other.is_a?(Namespace) && name == other.name && user_id == other.user_id
  end
end
