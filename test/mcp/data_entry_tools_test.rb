require "test_helper"
require_relative "mcp_test_helper"

class McpDataEntryToolsTest < ActionDispatch::IntegrationTest
  include McpTestHelper

  setup do
    @user = users(:one)
    @form = Form.create!(user: @user, name: "Morning", namespace: "health")
    @section = Section.create!(user: @user, name: "Body", namespace: "health")
    FormSection.create!(form: @form, section: @section, position: 0)
    @weight = add_question("Weight", "number")
    @mood = add_question("Mood", "range", range_min: 1, range_max: 5)
    @slept = add_question("Slept well", "bool")
    @note = add_question("Note", "string")
  end

  test "submit_form creates a response with one answer per question" do
    result = tool_ok("submit_form", {
      form_id: @form.id,
      answers: [
        { question_id: @weight.id, value: 72.5 },
        { question_id: @mood.id, value: 4 },
        { question_id: @slept.id, value: true },
        { question_id: @note.id, value: "Felt good" }
      ]
    })

    response = Response.find(result["id"])
    assert_equal @form, response.form
    assert_equal "health", response.namespace
    values = response.answers.to_h { |a| [ a.question_id, a.value ] }
    assert_equal({ @weight.id => 72.5, @mood.id => 4.0, @slept.id => true, @note.id => "Felt good" }, values)
    assert response.answers.all? { |a| a.namespace == "health" && a.user == @user }
    assert_equal 4, result["answers"].size
  end

  test "submit_form stores answers exactly as the survey page does" do
    tool_ok("submit_form", { form_id: @form.id, answers: [ { question_id: @slept.id, value: false } ] })
    mcp_answer = Answer.order(:id).last

    login_as(@user)
    post submit_survey_form_path(@form), params: { answers: { @slept.id => { value: "0" } } }
    web_answer = Answer.order(:id).last

    %i[answer_type string_value number_value bool_value namespace user_id question_id].each do |attr|
      assert_equal web_answer.public_send(attr), mcp_answer.public_send(attr), attr
    end
  end

  test "submit_form clears the form's draft" do
    FormDraft.create!(user: @user, form: @form, draft_data: { "x" => "1" })
    tool_ok("submit_form", { form_id: @form.id, answers: [ { question_id: @weight.id, value: 70 } ] })
    refute FormDraft.exists?(user: @user, form: @form)
  end

  test "submit_form with recorded_at backdates the response and its answers" do
    tool_ok("submit_form", {
      form_id: @form.id, recorded_at: "2026-10-01 07:30",
      answers: [ { question_id: @weight.id, value: 70 }, { question_id: @mood.id, value: 3 } ]
    })

    response = Response.order(:id).last
    expected = Time.zone.parse("2026-10-01 07:30")
    assert_in_delta expected, response.created_at, 1
    response.answers.each { |a| assert_in_delta expected, a.created_at, 2 }
  end

  test "submit_form rejects values that don't fit the question" do
    assert_match "a number from 1 to 5", tool_error("submit_form", { form_id: @form.id, answers: [ { question_id: @mood.id, value: 9 } ] })
    assert_match "a number", tool_error("submit_form", { form_id: @form.id, answers: [ { question_id: @weight.id, value: "heavy" } ] })
    assert_match "true or false", tool_error("submit_form", { form_id: @form.id, answers: [ { question_id: @slept.id, value: "yes" } ] })
    assert_match "non-empty string", tool_error("submit_form", { form_id: @form.id, answers: [ { question_id: @note.id, value: "" } ] })
  end

  test "submit_form rejects questions not in the form, duplicates, and bad dates" do
    other = Question.create!(user: @user, name: "Elsewhere", question_type: "number")
    assert_match "not in form", tool_error("submit_form", { form_id: @form.id, answers: [ { question_id: other.id, value: 1 } ] })
    assert_match "twice", tool_error("submit_form", {
      form_id: @form.id, answers: [ { question_id: @weight.id, value: 1 }, { question_id: @weight.id, value: 2 } ]
    })
    assert_match "Invalid date", tool_error("submit_form", {
      form_id: @form.id, recorded_at: "not a date", answers: [ { question_id: @weight.id, value: 1 } ]
    })
  end

  test "a rejected submission saves nothing" do
    assert_no_difference [ "Response.count", "Answer.count" ] do
      tool_error("submit_form", { form_id: @form.id, answers: [ { question_id: @weight.id, value: 1 }, { question_id: @mood.id, value: 99 } ] })
    end
  end

  test "submit_form can't use another user's form" do
    assert_match "Not found", tool_error("submit_form", { form_id: forms(:two).id, answers: [ { question_id: 1, value: 1 } ] })
  end

  test "answer_question records a standalone answer in the question's namespace" do
    result = tool_ok("answer_question", { question_id: @weight.id, value: 71 })
    answer = Answer.find(result["id"])
    assert_nil answer.response
    assert_equal 71.0, answer.number_value
    assert_equal "health", answer.namespace
  end

  test "answer_question checks the value" do
    assert_match "a number from 1 to 5", tool_error("answer_question", { question_id: @mood.id, value: 0 })
  end

  test "update_answer changes the value and namespace" do
    answer = AnswerSubmission.call(question: @weight, user: @user, value: "70")
    result = tool_ok("update_answer", { answer_id: answer.id, value: 69.5, namespace: "health.weight" })

    assert_equal 69.5, result["value"]
    assert_equal "health.weight", answer.reload.namespace
  end

  test "update_answer can move an answer to another question of the same type" do
    answer = AnswerSubmission.call(question: @weight, user: @user, value: "70")
    other = Question.create!(user: @user, name: "Weight (kg)", question_type: "number")

    tool_ok("update_answer", { answer_id: answer.id, question_id: other.id })
    assert_equal other, answer.reload.question
    assert_match "is a bool question", tool_error("update_answer", { answer_id: answer.id, question_id: @slept.id })
  end

  test "update_response moves the response and shifts its answers with it" do
    response = SurveySubmission.call(form: @form, user: @user, answers: { @weight.id => "70", @mood.id => "3" })
    response.answers.each_with_index { |a, i| a.update_columns(created_at: response.created_at + i.minutes) }
    offsets = response.answers.reload.map { |a| a.created_at - response.created_at }

    tool_ok("update_response", { response_id: response.id, recorded_at: "2026-09-15 20:00" })

    response.reload
    assert_in_delta Time.zone.parse("2026-09-15 20:00"), response.created_at, 1
    assert_equal offsets.map(&:round), response.answers.map { |a| (a.created_at - response.created_at).round }
  end

  test "update_response behaves like the web edit page" do
    response = SurveySubmission.call(form: @form, user: @user, answers: { @weight.id => "70" })
    login_as(@user)
    patch response_path(response), params: { response: { response_datetime: "2026-09-15T20:00" } }
    web_time = response.reload.created_at

    other = SurveySubmission.call(form: @form, user: @user, answers: { @weight.id => "70" })
    tool_ok("update_response", { response_id: other.id, recorded_at: "2026-09-15T20:00" })
    assert_equal web_time, other.reload.created_at
  end

  test "update_response changes answer values in the response" do
    response = SurveySubmission.call(form: @form, user: @user, answers: { @weight.id => "70", @slept.id => "1" })
    weight_answer = response.answers.find_by(question: @weight)
    slept_answer = response.answers.find_by(question: @slept)

    tool_ok("update_response", {
      response_id: response.id,
      answers: [ { answer_id: weight_answer.id, value: 68 }, { answer_id: slept_answer.id, value: false } ]
    })
    assert_equal 68.0, weight_answer.reload.number_value
    assert_equal false, slept_answer.reload.bool_value
  end

  test "update_response rejects answers from another response" do
    response = SurveySubmission.call(form: @form, user: @user, answers: { @weight.id => "70" })
    stray = AnswerSubmission.call(question: @weight, user: @user, value: "1")
    assert_match "not in response", tool_error("update_response", { response_id: response.id, answers: [ { answer_id: stray.id, value: 2 } ] })
  end

  private

  def add_question(name, type, **attrs)
    question = Question.create!(user: @user, name: name, question_type: type, namespace: "health", **attrs)
    SectionQuestion.create!(section: @section, question: question, position: SectionQuestion.next_position_for(section_id: @section.id))
    question
  end
end
