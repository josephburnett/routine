require "test_helper"

class ResponseUpdateTest < ActiveSupport::TestCase
  setup do
    @response = SurveySubmission.call(form: forms(:one), user: users(:one), answers: { questions(:one).id => "5" })
    @answer = @response.answers.first
  end

  test "moving the response shifts its answers by the same amount" do
    gap = @answer.created_at - @response.created_at
    ResponseUpdate.call(response: @response, datetime: "2026-01-02 09:00")

    assert_in_delta Time.zone.parse("2026-01-02 09:00"), @response.reload.created_at, 1
    assert_in_delta gap, @answer.reload.created_at - @response.created_at, 1
  end

  test "updates answer values" do
    ResponseUpdate.call(response: @response, answers: [ { id: @answer.id, number_value: 9 } ])
    assert_equal 9.0, @answer.reload.number_value
  end

  test "skips answers marked for removal" do
    ResponseUpdate.call(response: @response, answers: [ { id: @answer.id, number_value: 9, _destroy: "1" } ])
    assert_equal 5.0, @answer.reload.number_value
  end

  test "rejects a bad date and changes nothing" do
    assert_raises(ResponseUpdate::InvalidDatetime) do
      ResponseUpdate.call(response: @response, answers: [ { id: @answer.id, number_value: 9 } ], datetime: "nonsense")
    end
    assert_equal 5.0, @answer.reload.number_value
  end
end
