require "test_helper"

class SectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    login_as_user_one
  end
  test "should get index" do
    get sections_path
    assert_response :success
  end

  test "should soft delete section" do
    section = sections(:one)
    patch soft_delete_section_path(section)
    assert_redirected_to sections_path
    assert section.reload.deleted
  end
end
