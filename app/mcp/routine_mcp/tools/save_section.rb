module RoutineMcp
  module Tools
    class SaveSection < BaseTool
      tool_name "save_section"
      description <<~TEXT
        Create a section, or update one when id is given (only the fields you pass
        change). Creating with form_id makes it inside that form, as the form page does:
        it takes the form's namespace and is added at the end. Add questions with
        save_question (section_id) or arrange (relation section_questions).
      TEXT
      input_schema(
        properties: {
          id: { type: "integer", description: "Omit to create" },
          name: { type: "string" },
          prompt: { type: "string", description: "Text shown above the section's questions" },
          namespace: { type: "string", description: "Ignored when creating with form_id" },
          form_id: { type: "integer", description: "When creating: create it inside this form" }
        }
      )
      annotations(**WRITE)

      def self.run(user, id: nil, form_id: nil, **args)
        raise ToolError, "form_id only applies when creating; use arrange to add an existing section to a form" if id && form_id

        if id
          section = find!(user, "section", id)
          section.assign_attributes(given(args, :name, :prompt, :namespace))
          return Serialize.detail(save!(section))
        end

        form = form_id && find!(user, "form", form_id)
        section = user.sections.build(given(args, :name, :prompt, :namespace))
        section.namespace = form.namespace if form

        Section.transaction do
          save!(section)
          Membership.add(:form_sections, form, section) if form
        end
        Serialize.detail(section)
      end
    end
  end
end
