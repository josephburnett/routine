# Submits a form: creates a Response with one Answer per question, then clears
# the user's draft for the form.
#
# answers: { question_id => raw value }. Questions that aren't in the form are
# ignored. Answers that fail validation (e.g. a blank string) are skipped, as
# the web form always has done; check response.answers for what was saved.
class SurveySubmission
  attr_reader :response

  def self.call(...)
    new(...).call
  end

  def initialize(form:, user:, answers:)
    @form = form
    @user = user
    @answers = answers || {}
  end

  # Returns the saved Response, or nil if it couldn't be saved.
  def call
    @response = Response.new(form: @form, user: @user, namespace: @form.namespace)
    return nil unless @response.save

    questions = form_questions_by_id
    @answers.each do |question_id, raw|
      question = questions[question_id.to_i]
      next unless question

      Answer.new(
        response: @response,
        question: question,
        user: @user,
        answer_type: question.question_type,
        namespace: @form.namespace,
        **AnswerValue.attributes_for(question.question_type, raw)
      ).save
    end

    FormDraft.where(user: @user, form: @form).destroy_all
    @response.answers.reset
    @response
  end

  private

  def form_questions_by_id
    @form.sections.flat_map(&:questions).select { |q| q.user_id == @user.id }.index_by(&:id)
  end
end
