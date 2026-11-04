module RoutineMcp
  module Tools
    class SaveQuestion < BaseTool
      tool_name "save_question"
      description <<~TEXT
        Create a question, or update one when id is given (only the fields you pass
        change). Types: string, number, bool, range (range needs range_min < range_max).
        Creating with section_id makes it inside that section, as the section page does:
        it takes the section's namespace and is added at the end.
      TEXT
      input_schema(
        properties: {
          id: { type: "integer", description: "Omit to create" },
          name: { type: "string" },
          question_type: { type: "string", enum: %w[string number bool range] },
          range_min: { type: "number" },
          range_max: { type: "number" },
          namespace: { type: "string", description: "Ignored when creating with section_id" },
          section_id: { type: "integer", description: "When creating: create it inside this section" }
        }
      )
      annotations(**WRITE)

      FIELDS = %i[name question_type range_min range_max namespace].freeze

      def self.run(user, id: nil, section_id: nil, **args)
        raise ToolError, "section_id only applies when creating; use arrange to add an existing question to a section" if id && section_id

        if id
          question = find!(user, "question", id)
          question.assign_attributes(given(args, *FIELDS))
          return Serialize.detail(save!(question))
        end

        section = section_id && find!(user, "section", section_id)
        question = user.questions.build(given(args, *FIELDS))
        question.namespace = section.namespace if section

        Question.transaction do
          save!(question)
          Membership.add(:section_questions, section, question) if section
        end
        Serialize.detail(question)
      end
    end
  end
end
