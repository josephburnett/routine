require "test_helper"

class SurveySubmissionTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @form = forms(:one)
    @question = questions(:one)
  end

  test "creates a response with answers in the form's namespace and clears the draft" do
    @form.update!(namespace: "daily")
    FormDraft.find_or_create_by!(user: @user, form: @form)

    response = SurveySubmission.call(form: @form, user: @user, answers: { @question.id.to_s => "4" })

    assert response.persisted?
    assert_equal "daily", response.namespace
    answer = response.answers.sole
    assert_equal [ 4.0, "daily", @question ], [ answer.number_value, answer.namespace, answer.question ]
    refute FormDraft.exists?(user: @user, form: @form)
  end

  test "ignores questions that aren't in the form or belong to someone else" do
    stray = Question.create!(user: @user, name: "Stray", question_type: "number")
    theirs = questions(:two)

    response = SurveySubmission.call(form: @form, user: @user, answers: { stray.id => "1", theirs.id => "1", @question.id => "2" })
    assert_equal [ @question.id ], response.answers.map(&:question_id)
  end

  test "skips answers that fail validation, as the web form did" do
    note = Question.create!(user: @user, name: "Note", question_type: "string")
    SectionQuestion.create!(section: sections(:one), question: note, position: 5)

    response = SurveySubmission.call(form: @form, user: @user, answers: { note.id => "", @question.id => "3" })
    assert_equal [ @question.id ], response.answers.map(&:question_id)
  end
end
