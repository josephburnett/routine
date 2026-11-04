module RoutineMcp
  module Tools
    class UpdateResponse < BaseTool
      tool_name "update_response"
      description <<~TEXT
        Edit a submitted response, like the response's Edit page: change answer values,
        move it to another date and time, or change its namespace. Moving a response
        shifts all its answers by the same amount, so they stay together. recorded_at is
        ISO 8601, or "YYYY-MM-DD HH:MM" in the app's Pacific time zone.
      TEXT
      input_schema(
        properties: {
          response_id: { type: "integer" },
          recorded_at: { type: "string" },
          answers: {
            type: "array",
            items: {
              type: "object",
              properties: { answer_id: { type: "integer" }, value: {} },
              required: %w[answer_id value]
            }
          },
          namespace: { type: "string" }
        },
        required: [ "response_id" ]
      )
      annotations(**IDEMPOTENT_WRITE)

      def self.run(user, response_id:, recorded_at: nil, answers: [], **args)
        response = find!(user, "response", response_id)
        recorded_at = parse_time!(recorded_at)

        answer_changes = answers.map do |entry|
          answer = response.answers.not_deleted.find_by(id: entry[:answer_id]) ||
                   raise(ToolError, "Answer #{entry[:answer_id]} is not in response #{response.id}")
          { id: answer.id, **AnswerValue.attributes_for(answer.answer_type, AnswerInput.to_form_value!(answer.question, entry[:value])) }
        end

        ::Response.transaction do
          ResponseUpdate.call(response: response, answers: answer_changes, datetime: recorded_at)
          save!(response.tap { |r| r.namespace = args[:namespace] }) if args.key?(:namespace)
        end

        Serialize.detail(response.reload)
      end
    end
  end
end
