require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "action_button renders a form that sends PATCH by default" do
    html = action_button("Float", "/remembers/1/float", class: "btn")

    form = Nokogiri::HTML5.fragment(html).at_css("form.action-button-form")
    assert form, "expected a form with class action-button-form"
    assert_equal "post", form["method"]
    assert_equal "/remembers/1/float", form["action"]
    assert_equal "patch", form.at_css("input[name=_method]")["value"]
    assert_equal "Float", form.at_css("button[type=submit].btn").text
    assert_nil form["data-turbo-confirm"]
  end

  test "action_button sends the given method" do
    form = Nokogiri::HTML5.fragment(action_button("Logout", "/logout", method: :delete)).at_css("form")
    assert_equal "delete", form.at_css("input[name=_method]")["value"]
  end

  test "action_button puts the confirm message where Turbo reads it" do
    form = Nokogiri::HTML5.fragment(action_button("Retire", "/remembers/1/retire", confirm: "Sure?")).at_css("form")
    assert_equal "Sure?", form["data-turbo-confirm"]
  end

  test "action_button keeps query params in the form action" do
    form = Nokogiri::HTML5.fragment(action_button("↑", "/sections/1/move_question_up?question_id=7")).at_css("form")
    assert_equal "/sections/1/move_question_up?question_id=7", form["action"]
  end
end
