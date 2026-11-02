require "test_helper"

class AnswersControllerTest < ActionDispatch::IntegrationTest
  setup do
    login_as_user_one
  end
  test "should get index" do
    get answers_path
    assert_response :success
  end

  test "should get show" do
    get answer_path(answers(:one))
    assert_response :success
  end

  test "should soft delete answer" do
    answer = answers(:one)
    patch soft_delete_answer_path(answer)
    assert_redirected_to answers_path
    assert answer.reload.deleted
  end
end
