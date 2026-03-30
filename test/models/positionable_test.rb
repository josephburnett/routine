require "test_helper"

class PositionableTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @form = forms(:one)
    @section = sections(:one)

    # Clear existing associations
    FormSection.where(form: @form).destroy_all

    # Create 3 sections for the form
    @s1 = Section.create!(name: "Section A", user: @user)
    @s2 = Section.create!(name: "Section B", user: @user)
    @s3 = Section.create!(name: "Section C", user: @user)

    @fs1 = FormSection.create!(form: @form, section: @s1, position: 0)
    @fs2 = FormSection.create!(form: @form, section: @s2, position: 1)
    @fs3 = FormSection.create!(form: @form, section: @s3, position: 2)
  end

  test "next_position_for returns max position plus one" do
    assert_equal 3, FormSection.next_position_for(form_id: @form.id)
  end

  test "next_position_for returns 1 when no records exist" do
    other_form = Form.create!(name: "Other", user: @user)
    assert_equal 1, FormSection.next_position_for(form_id: other_form.id)
  end

  test "move_higher swaps with the item above" do
    @fs2.move_higher!

    @fs1.reload
    @fs2.reload

    assert_equal 1, @fs1.position
    assert_equal 0, @fs2.position
  end

  test "move_higher does nothing for first item" do
    @fs1.move_higher!
    @fs1.reload
    assert_equal 0, @fs1.position
  end

  test "move_lower swaps with the item below" do
    @fs2.move_lower!

    @fs2.reload
    @fs3.reload

    assert_equal 2, @fs2.position
    assert_equal 1, @fs3.position
  end

  test "move_lower does nothing for last item" do
    @fs3.move_lower!
    @fs3.reload
    assert_equal 2, @fs3.position
  end

  test "move_higher only affects items in same scope" do
    other_form = Form.create!(name: "Other Form", user: @user)
    other_fs = FormSection.create!(form: other_form, section: @s1, position: 0)

    @fs2.move_higher!

    other_fs.reload
    assert_equal 0, other_fs.position, "Other form's section should not be affected"
  end

  test "apply_sort reorders by name ascending" do
    FormSection.apply_sort!({ form_id: @form.id }, :section, "name", "asc")

    @fs1.reload
    @fs2.reload
    @fs3.reload

    sections_by_position = [ @fs1, @fs2, @fs3 ].sort_by(&:position).map { |fs| fs.section.name }
    assert_equal [ "Section A", "Section B", "Section C" ], sections_by_position
  end

  test "apply_sort reorders by name descending" do
    FormSection.apply_sort!({ form_id: @form.id }, :section, "name", "desc")

    @fs1.reload
    @fs2.reload
    @fs3.reload

    sections_by_position = [ @fs1, @fs2, @fs3 ].sort_by(&:position).map { |fs| fs.section.name }
    assert_equal [ "Section C", "Section B", "Section A" ], sections_by_position
  end

  test "apply_sort reorders by created_at" do
    # Set distinct created_at values
    @s3.update_columns(created_at: 1.day.ago)
    @s1.update_columns(created_at: 2.days.ago)
    @s2.update_columns(created_at: Time.current)

    FormSection.apply_sort!({ form_id: @form.id }, :section, "created_at", "asc")

    @fs1.reload
    @fs2.reload
    @fs3.reload

    sections_by_position = [ @fs1, @fs2, @fs3 ].sort_by(&:position).map { |fs| fs.section.name }
    assert_equal [ "Section A", "Section C", "Section B" ], sections_by_position
  end

  test "ordered scope returns items in position order" do
    results = FormSection.where(form: @form).ordered
    assert_equal [ 0, 1, 2 ], results.map(&:position)
  end
end
