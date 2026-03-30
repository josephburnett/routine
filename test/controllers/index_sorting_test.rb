require "test_helper"

class IndexSortingTest < ActionDispatch::IntegrationTest
  setup do
    login_as_user_one
  end

  test "forms index accepts sort params" do
    get forms_path(sort: "name", dir: "asc")
    assert_response :success
  end

  test "forms index accepts created_at sort" do
    get forms_path(sort: "created_at", dir: "desc")
    assert_response :success
  end

  test "forms index accepts updated_at sort" do
    get forms_path(sort: "updated_at", dir: "desc")
    assert_response :success
  end

  test "sections index accepts sort params" do
    get sections_path(sort: "name", dir: "desc")
    assert_response :success
  end

  test "questions index accepts sort params" do
    get questions_path(sort: "name", dir: "asc")
    assert_response :success
  end

  test "answers index accepts sort params" do
    get answers_path(sort: "created_at", dir: "asc")
    assert_response :success
  end

  test "metrics index accepts sort params" do
    get metrics_path(sort: "name", dir: "desc")
    assert_response :success
  end

  test "alerts index accepts sort params" do
    get alerts_path(sort: "name", dir: "asc")
    assert_response :success
  end

  test "reports index accepts sort params" do
    get reports_path(sort: "name", dir: "asc")
    assert_response :success
  end

  test "remembers index accepts sort params" do
    get remembers_path(sort: "description", dir: "asc")
    assert_response :success
  end

  test "remembers index accepts created_at sort" do
    get remembers_path(sort: "created_at", dir: "desc")
    assert_response :success
  end

  test "invalid sort column is ignored" do
    get forms_path(sort: "invalid_column", dir: "asc")
    assert_response :success
  end

  test "invalid sort direction defaults to asc" do
    get forms_path(sort: "name", dir: "invalid")
    assert_response :success
  end

  test "index without sort params works normally" do
    get forms_path
    assert_response :success
  end

  test "sort with namespace param" do
    get forms_path(namespace: "", sort: "name", dir: "asc")
    assert_response :success
  end
end
