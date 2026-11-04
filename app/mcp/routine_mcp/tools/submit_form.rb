module RoutineMcp
  module Tools
    class SubmitForm < BaseTool
      tool_name "submit_form"
      description <<~TEXT
        Submit a form, as filling it in on the survey page does: creates a response with one
        answer per question and clears the form's saved draft. Get the form with get_item
        first to see its questions. Values: strings for string questions, numbers for number
        and range questions (range must be within its min and max), true/false for bool.
        Questions you leave out get no answer. recorded_at backdates the response and its
        answers (ISO 8601, or "YYYY-MM-DD HH:MM" in the app's Pacific time zone), the same
        as editing the response's date afterwards.
      TEXT
      input_schema(
        properties: {
          form_id: { type: "integer" },
          answers: {
            type: "array",
            items: {
              type: "object",
              properties: {
                question_id: { type: "integer" },
                value: { description: "String, number or boolean, matching the question type" }
              },
              required: %w[question_id value]
            }
          },
          recorded_at: { type: "string" }
        },
        required: %w[form_id answers]
      )
      annotations(**WRITE)

      def self.run(user, form_id:, answers:, recorded_at: nil)
        form = find!(user, "form", form_id)
        recorded_at = parse_time!(recorded_at)
        questions = form.sections.not_deleted.flat_map { |s| s.questions.not_deleted }.index_by(&:id)
        raise ToolError, "Give at least one answer" if answers.empty?

        values = answers.each_with_object({}) do |entry, out|
          question = questions[entry[:question_id]] || raise(ToolError, "Question #{entry[:question_id]} is not in form #{form.id}")
          raise ToolError, "Question #{question.id} is answered twice" if out.key?(question.id)

          out[question.id] = AnswerInput.to_form_value!(question, entry[:value])
        end

        response = nil
        ::Response.transaction do
          response = SurveySubmission.call(form: form, user: user, answers: values)
          raise ToolError, "Couldn't save the response" unless response

          ResponseUpdate.call(response: response, datetime: recorded_at) if recorded_at
        end

        Serialize.detail(response.reload)
      end
    end
  end
end
