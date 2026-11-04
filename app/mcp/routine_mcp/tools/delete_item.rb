module RoutineMcp
  module Tools
    class DeleteItem < BaseTool
      tool_name "delete_item"
      description <<~TEXT
        Delete an item, like its Delete button. Deleting a response also deletes its
        answers. Deleted items disappear from the app and from these tools.
      TEXT
      input_schema(
        properties: {
          type: { type: "string", enum: TYPES.keys },
          id: { type: "integer" }
        },
        required: %w[type id]
      )
      annotations(**DESTRUCTIVE)

      def self.run(user, type:, id:)
        item = find!(user, type, id)
        item.soft_delete!
        { deleted: Serialize.summary(item) }
      end
    end
  end
end
