module RoutineMcp
  module Tools
    class UpdateAnswer < BaseTool
      tool_name "update_answer"
      description <<~TEXT
        Edit an answer, like the answer's Edit page: its value, the question it answers,
        or its namespace. Only the fields you pass change. To change when an answer was
        recorded, use update_response on its response (answers move with their response).
      TEXT
      input_schema(
        properties: {
          answer_id: { type: "integer" },
          value: { description: "New value, matching the question type" },
          question_id: { type: "integer", description: "Move the answer to another of your questions (same type)" },
          namespace: { type: "string" }
        },
        required: [ "answer_id" ]
      )
      annotations(**IDEMPOTENT_WRITE)

      def self.run(user, answer_id:, **args)
        answer = find!(user, "answer", answer_id)

        if args.key?(:question_id)
          question = find!(user, "question", args[:question_id])
          raise ToolError, "Question #{question.id} is a #{question.question_type} question, not #{answer.answer_type}" if question.question_type != answer.answer_type

          answer.question = question
        end
        answer.namespace = args[:namespace] if args.key?(:namespace)
        if args.key?(:value)
          answer.assign_attributes(AnswerValue.attributes_for(answer.answer_type, AnswerInput.to_form_value!(answer.question, args[:value])))
        end

        save!(answer)
        Serialize.answer(answer)
      end
    end
  end
end
