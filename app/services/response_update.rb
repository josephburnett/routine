# Edits a submitted Response: changes answer values, and moves the response to
# a new date and time. Moving a response shifts all its answers by the same
# amount, so they stay together.
module ResponseUpdate
  class InvalidDatetime < StandardError; end

  # answers: [{ id:, string_value:/number_value:/bool_value:/answer_type: }]
  # datetime: a Time, or a string Time.zone can parse
  def self.call(response:, answers: [], datetime: nil)
    Response.transaction do
      Array(answers).each do |attrs|
        attrs = attrs.to_h.symbolize_keys
        next if attrs[:_destroy].to_s == "1"

        answer = response.answers.find(attrs[:id])
        answer.update!(attrs.except(:id, :_destroy))
      end

      if datetime.present?
        new_datetime = datetime.is_a?(String) ? Time.zone.parse(datetime) : datetime
        raise InvalidDatetime, "Invalid date and time: #{datetime}" unless new_datetime

        response.update_timestamp!(new_datetime)
      end
    end
    response
  rescue ArgumentError
    raise InvalidDatetime, "Invalid date and time: #{datetime}"
  end
end
