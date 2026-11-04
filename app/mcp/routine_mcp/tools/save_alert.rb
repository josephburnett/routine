module RoutineMcp
  module Tools
    class SaveAlert < BaseTool
      tool_name "save_alert"
      description <<~TEXT
        Create an alert, or update one when id is given (only the fields you pass change).
        An alert watches a metric and activates when its last `delay` points are all past
        the threshold in the given direction. message is included when it's reported.
      TEXT
      input_schema(
        properties: {
          id: { type: "integer", description: "Omit to create" },
          name: { type: "string" },
          metric_id: { type: "integer" },
          threshold: { type: "number" },
          direction: { type: "string", enum: %w[above below at_or_above at_or_below] },
          delay: { type: "integer", minimum: 1, description: "How many points in a row (default 1)" },
          message: { type: "string" },
          disabled: { type: "boolean" },
          namespace: { type: "string" }
        }
      )
      annotations(**WRITE)

      def self.run(user, id: nil, **args)
        alert = id ? find!(user, "alert", id) : user.alerts.build
        alert.assign_attributes(given(args, :name, :threshold, :direction, :delay, :message, :disabled, :namespace))
        alert.metric = find!(user, "metric", args[:metric_id]) if args.key?(:metric_id)

        Serialize.detail(save!(alert))
      end
    end
  end
end
