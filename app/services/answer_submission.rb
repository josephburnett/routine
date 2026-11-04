# Answers a single question outside of a form.
module AnswerSubmission
  # Returns the Answer, saved or with errors.
  def self.call(question:, user:, value:)
    answer = Answer.new(
      question: question,
      user: user,
      answer_type: question.question_type,
      namespace: question.namespace,
      **AnswerValue.attributes_for(question.question_type, value)
    )
    answer.save
    answer
  end
end
