module RoutineMcp
  module Tools
    class MoveToNamespace < BaseTool
      tool_name "move_to_namespace"
      description <<~TEXT
        Move items to another namespace, like the bulk move on the Namespaces page.
        With cascade (the default) related items move too: a form takes its responses,
        their answers, its sections, their questions and those questions' answers; a
        section takes its questions and their answers; a question takes its answers.
        Returns how many items moved in total.
      TEXT
      input_schema(
        properties: {
          items: {
            type: "object",
            description: "Ids to move by type, e.g. { \"forms\": [1], \"questions\": [4, 5] }",
            properties: NamespaceMove::MODELS.keys.index_with { { type: "array", items: { type: "integer" } } },
            additionalProperties: false
          },
          target_namespace: { type: "string", description: "\"\" for root" },
          cascade: { type: "boolean", description: "Default true" }
        },
        required: %w[items target_namespace]
      )
      annotations(**IDEMPOTENT_WRITE)

      def self.run(user, items:, target_namespace:, cascade: true)
        items = items.transform_keys(&:to_s)
        items.each { |type, ids| ids.each { |id| find!(user, type.singularize, id) } }

        moved = NamespaceMove.call(user: user, entities: items, target_namespace: target_namespace, cascade: cascade)
        { moved: moved, target_namespace: target_namespace }
      end
    end
  end
end
