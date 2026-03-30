require "test_helper"

class FormsControllerTest < ActionDispatch::IntegrationTest
  setup do
    login_as_user_one
    @user = users(:one)
    @form = forms(:one)
  end

  test "should get index" do
    get forms_path
    assert_response :success
  end

  test "should get index with sort params" do
    get forms_path(sort: "name", dir: "asc")
    assert_response :success
  end

  test "should get index with sort by created_at desc" do
    get forms_path(sort: "created_at", dir: "desc")
    assert_response :success
  end

  test "should get show" do
    get form_path(@form)
    assert_response :success
  end

  test "add_section assigns next position" do
    section = Section.create!(name: "New Section #{SecureRandom.hex(4)}", user: @user)

    patch add_section_form_path(@form), params: { section_id: section.id }
    assert_redirected_to form_path(@form)

    fs = FormSection.find_by(form: @form, section: section)
    assert fs, "FormSection should be created"
    assert fs.position >= 0
  end

  test "remove_section destroys the join record" do
    section = Section.create!(name: "To Remove #{SecureRandom.hex(4)}", user: @user)
    FormSection.create!(form: @form, section: section, position: 99)

    assert_difference "FormSection.count", -1 do
      patch remove_section_form_path(@form), params: { section_id: section.id }
    end
    assert_redirected_to edit_form_path(@form)
  end

  test "move_section_up swaps positions" do
    FormSection.where(form: @form).destroy_all
    s1 = Section.create!(name: "First", user: @user)
    s2 = Section.create!(name: "Second", user: @user)
    FormSection.create!(form: @form, section: s1, position: 0)
    FormSection.create!(form: @form, section: s2, position: 1)

    patch move_section_up_form_path(@form), params: { section_id: s2.id }
    assert_redirected_to form_path(@form)

    assert_equal 1, FormSection.find_by(form: @form, section: s1).position
    assert_equal 0, FormSection.find_by(form: @form, section: s2).position
  end

  test "move_section_down swaps positions" do
    FormSection.where(form: @form).destroy_all
    s1 = Section.create!(name: "First", user: @user)
    s2 = Section.create!(name: "Second", user: @user)
    FormSection.create!(form: @form, section: s1, position: 0)
    FormSection.create!(form: @form, section: s2, position: 1)

    patch move_section_down_form_path(@form), params: { section_id: s1.id }
    assert_redirected_to form_path(@form)

    assert_equal 1, FormSection.find_by(form: @form, section: s1).position
    assert_equal 0, FormSection.find_by(form: @form, section: s2).position
  end

  test "sort_sections reorders by name" do
    FormSection.where(form: @form).destroy_all
    s_b = Section.create!(name: "Bravo", user: @user)
    s_a = Section.create!(name: "Alpha", user: @user)
    FormSection.create!(form: @form, section: s_b, position: 0)
    FormSection.create!(form: @form, section: s_a, position: 1)

    patch sort_sections_form_path(@form), params: { sort_by: "name", direction: "asc" }
    assert_redirected_to form_path(@form)

    assert_equal 0, FormSection.find_by(form: @form, section: s_a).position
    assert_equal 1, FormSection.find_by(form: @form, section: s_b).position
  end

  test "survey renders sections in position order" do
    FormSection.where(form: @form).destroy_all
    s1 = Section.create!(name: "Second Section", user: @user)
    s2 = Section.create!(name: "First Section", user: @user)
    FormSection.create!(form: @form, section: s1, position: 1)
    FormSection.create!(form: @form, section: s2, position: 0)

    get survey_form_path(@form)
    assert_response :success

    body = response.body
    first_pos = body.index("First Section")
    second_pos = body.index("Second Section")
    assert first_pos < second_pos, "First Section should appear before Second Section in survey"
  end
end
