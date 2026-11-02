require "test_helper"

class ResponsesControllerTest < ActionDispatch::IntegrationTest
  setup do
    login_as_user_one
  end
  test "should get index" do
    get responses_path
    assert_response :success
  end

  test "should get show" do
    get response_path(responses(:one))
    assert_response :success
  end

  test "should soft delete response" do
    response = responses(:one)
    patch soft_delete_response_path(response)
    assert_redirected_to responses_path
    assert response.reload.deleted
  end
end
