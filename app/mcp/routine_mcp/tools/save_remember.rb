module RoutineMcp
  module Tools
    class SaveRemember < BaseTool
      tool_name "save_remember"
      description <<~TEXT
        Create a remember, or update one when id is given (only the fields you pass
        change). New remembers start floating with decay 1.0. Use remember_action to pin,
        float, bump, retire or set decay.
      TEXT
      input_schema(
        properties: {
          id: { type: "integer", description: "Omit to create" },
          description: { type: "string", description: "What to remember (shown on the card front)" },
          background: { type: "string", description: "Notes shown when the card is flipped" },
          namespace: { type: "string" }
        }
      )
      annotations(**WRITE)

      def self.run(user, id: nil, **args)
        remember = id ? find!(user, "remember", id) : user.remembers.build
        raise ToolError, "description is required" if id.nil? && args[:description].blank?

        remember.assign_attributes(given(args, :description, :background, :namespace))
        Serialize.remember(save!(remember))
      end
    end
  end
end
