# Turns a submitted value into the answer columns for a question type.
# Shared by the web forms and the MCP tools so both store answers the same way.
module AnswerValue
  TRUE_VALUES = [ "1", "true", true ].freeze

  def self.attributes_for(question_type, raw)
    case question_type
    when "string"
      { string_value: raw }
    when "number", "range"
      { number_value: raw.to_f }
    when "bool"
      { bool_value: TRUE_VALUES.include?(raw) }
    else
      {}
    end
  end
end
