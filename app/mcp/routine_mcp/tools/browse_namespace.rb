module RoutineMcp
  module Tools
    class BrowseNamespace < BaseTool
      tool_name "browse_namespace"
      description <<~TEXT
        Show one namespace (folder) like the Namespaces page: its child namespaces and the
        items directly in it, by type. Namespaces are dot-separated paths like "home.pool";
        "" is the root. As on the page, sections in a form, questions in a section, answers
        and responses are not listed here; use get_item on the parent or list_items.
      TEXT
      input_schema(
        properties: { namespace: { type: "string", description: "Namespace path; omit or \"\" for root" } }
      )
      annotations(**READ_ONLY)

      def self.run(user, namespace: "")
        ns = Namespace.find_for_user(user, namespace.to_s)
        {
          namespace: ns.name,
          parent_namespace: ns.name.present? ? ns.parent_namespace : nil,
          child_namespaces: ns.child_namespaces.map(&:name),
          items: ns.entities.transform_keys { |label| label.underscore }.transform_values { |items| items.map { |i| Serialize.summary(i) } }
        }
      end
    end
  end
end
