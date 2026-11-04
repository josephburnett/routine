module RoutineMcp
  # Checks a value Claude submits for a question, and converts it to what the
  # web form would have sent, so AnswerValue stores it the same way.
  module AnswerInput
    module_function

    def to_form_value!(question, value)
      case question.question_type
      when "string"
        raise_invalid(question, "a non-empty string") unless value.is_a?(String) && value.present?
        value
      when "number"
        number!(question, value).to_s
      when "range"
        number = number!(question, value)
        unless number.between?(question.range_min, question.range_max)
          raise_invalid(question, "a number from #{fmt(question.range_min)} to #{fmt(question.range_max)}")
        end
        number.to_s
      when "bool"
        raise_invalid(question, "true or false") unless [ true, false ].include?(value)
        value ? "1" : "0"
      else
        raise BaseTool::ToolError, "Question #{question.id} has an unknown type: #{question.question_type}"
      end
    end

    def number!(question, value)
      Float(value)
    rescue ArgumentError, TypeError
      raise_invalid(question, "a number")
    end

    def raise_invalid(question, expected)
      raise BaseTool::ToolError, "Question #{question.id} (#{question.name}) needs #{expected}"
    end

    def fmt(number)
      number.to_s.sub(/\.0\z/, "")
    end
  end
end
