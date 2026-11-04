module RoutineMcp
  module Tools
    class AnswerQuestion < BaseTool
      tool_name "answer_question"
      description <<~TEXT
        Answer one question on its own, outside a form, like the question's Answer page.
        The answer is recorded now and goes in the question's namespace. Value: a string
        for string questions, a number for number and range questions, true/false for bool.
      TEXT
      input_schema(
        properties: {
          question_id: { type: "integer" },
          value: { description: "String, number or boolean, matching the question type" }
        },
        required: %w[question_id value]
      )
      annotations(**WRITE)

      def self.run(user, question_id:, value:)
        question = find!(user, "question", question_id)
        answer = AnswerSubmission.call(question: question, user: user, value: AnswerInput.to_form_value!(question, value))
        raise ToolError, answer.errors.full_messages.to_sentence unless answer.persisted?

        Serialize.answer(answer)
      end
    end
  end
end
