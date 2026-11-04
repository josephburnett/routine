module RoutineMcp
  module Tools
    class GetItem < BaseTool
      tool_name "get_item"
      description <<~TEXT
        Get one item with its details and links: a form's sections and their questions,
        a section's questions and forms, a question's sections, metrics and last answer,
        a response's answers, a metric's sources and latest point, an alert's current
        status, a report's schedule, alerts, metrics and today's remembers.
      TEXT
      input_schema(
        properties: {
          type: { type: "string", enum: TYPES.keys },
          id: { type: "integer" }
        },
        required: %w[type id]
      )
      annotations(**READ_ONLY)

      def self.run(user, type:, id:)
        Serialize.detail(find!(user, type, id))
      end
    end
  end
end
