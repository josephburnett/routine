require "test_helper"

class FormSectionTest < ActiveSupport::TestCase
  test "validates uniqueness of form and section" do
    form = forms(:one)
    section = sections(:one)

    # The fixture already creates this association
    duplicate = FormSection.new(form: form, section: section, position: 99)
    assert_not duplicate.valid?
  end

  test "position_scope_column returns form_id" do
    assert_equal :form_id, FormSection.position_scope_column
  end
end
