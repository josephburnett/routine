module RoutineMcp
  module Tools
    class SaveForm < BaseTool
      tool_name "save_form"
      description <<~TEXT
        Create a form, or update one when id is given (only the fields you pass change).
        Add sections with save_section (form_id) or arrange (relation form_sections).
      TEXT
      input_schema(
        properties: {
          id: { type: "integer", description: "Omit to create" },
          name: { type: "string" },
          namespace: { type: "string" }
        }
      )
      annotations(**WRITE)

      def self.run(user, id: nil, **args)
        form = id ? find!(user, "form", id) : user.forms.build
        form.assign_attributes(given(args, :name, :namespace))
        Serialize.detail(save!(form))
      end
    end
  end
end
