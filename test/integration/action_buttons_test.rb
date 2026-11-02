require "test_helper"

# Non-GET actions must be real forms. A link with data-turbo-method only sends
# PATCH/DELETE when Turbo's JS handles the click; otherwise the browser follows
# it as a GET and the user gets a 404 (this happened with "Float").
class ActionButtonsTest < ActionDispatch::IntegrationTest
  setup do
    login_as_user_one
    @user = users(:one)
  end

  test "no view uses links with data-turbo-method" do
    offenders = Dir[Rails.root.join("app/views/**/*.erb")].select do |path|
      File.read(path).match?(/turbo[-_]method/)
    end
    assert_empty offenders.map { |p| Pathname(p).relative_path_from(Rails.root).to_s },
                 "use action_button instead of link_to with data-turbo-method"
  end

  test "remember show page uses forms for its actions" do
    remember = remembers(:floating_high)
    get remember_path(remember)
    assert_response :success

    assert_action_form pin_remember_path(remember)
    assert_action_form float_remember_path(remember)
    assert_action_form bump_up_remember_path(remember)
    assert_action_form bump_down_remember_path(remember)
    assert_action_form retire_remember_path(remember), confirm: "Retire this remember?"
    assert_no_turbo_method_links
  end

  test "remembers index uses forms for its row actions" do
    remember = remembers(:floating_high)
    get remembers_path
    assert_response :success

    assert_action_form pin_remember_path(remember)
    assert_action_form bump_up_remember_path(remember)
    assert_action_form bump_down_remember_path(remember)
    assert_action_form retire_remember_path(remember), confirm: "Retire this remember?"
    assert_no_turbo_method_links
  end

  test "edit pages use a confirmed form for delete" do
    {
      edit_remember_path(remembers(:floating_high)) => soft_delete_remember_path(remembers(:floating_high)),
      edit_metric_path(metrics(:one)) => soft_delete_metric_path(metrics(:one)),
      edit_question_path(questions(:one)) => soft_delete_question_path(questions(:one)),
      edit_answer_path(answers(:one)) => soft_delete_answer_path(answers(:one)),
      edit_response_path(responses(:one)) => soft_delete_response_path(responses(:one)),
      edit_report_path(reports(:one)) => soft_delete_report_path(reports(:one)),
      edit_section_path(sections(:one)) => soft_delete_section_path(sections(:one)),
      edit_form_path(forms(:one)) => soft_delete_form_path(forms(:one))
    }.each do |page, delete_path|
      get page
      assert_response :success, "GET #{page}"
      assert_action_form delete_path, confirm: /Are you sure/
      assert_no_turbo_method_links
    end
  end

  test "form pages use forms for move, remove and sort" do
    form = forms(:one)
    second = Section.create!(name: "Second #{SecureRandom.hex(4)}", user: @user)
    FormSection.create!(form: form, section: second, position: 1)
    first = sections(:one)

    [ form_path(form), edit_form_path(form) ].each do |page|
      get page
      assert_response :success
      assert_action_form move_section_down_form_path(form, section_id: first.id)
      assert_action_form move_section_up_form_path(form, section_id: second.id)
      assert_no_turbo_method_links
    end

    assert_action_form remove_section_form_path(form, section_id: second.id),
                       confirm: "Remove this section from the form?"

    get form_path(form)
    assert_sort_forms sort_sections_form_path(form)
  end

  test "section pages use forms for move, remove and sort" do
    section = sections(:one)
    second = Question.create!(name: "Second #{SecureRandom.hex(4)}", question_type: "number", user: @user)
    SectionQuestion.create!(section: section, question: second, position: 1)
    first = questions(:one)

    [ section_path(section), edit_section_path(section) ].each do |page|
      get page
      assert_response :success
      assert_action_form move_question_down_section_path(section, question_id: first.id)
      assert_action_form move_question_up_section_path(section, question_id: second.id)
      assert_no_turbo_method_links
    end

    assert_action_form remove_question_section_path(section, question_id: second.id),
                       confirm: "Remove this question from the section?"

    get section_path(section)
    assert_sort_forms sort_questions_section_path(section)
  end

  test "report page uses forms for move and sort" do
    report = reports(:one)
    alert = Alert.create!(name: "A #{SecureRandom.hex(4)}", metric: metrics(:one), threshold: 5, direction: "above", user: @user)
    ReportAlert.create!(report: report, alert: alert, position: 1)
    metric = Metric.create!(name: "M #{SecureRandom.hex(4)}", user: @user, resolution: "hour", width: "daily",
                            function: "answer", scale: 1.0, wrap: "none")
    ReportMetric.create!(report: report, metric: metric, position: 1)

    get report_path(report)
    assert_response :success

    assert_action_form move_alert_down_report_path(report, alert_id: alerts(:one).id)
    assert_action_form move_alert_up_report_path(report, alert_id: alert.id)
    assert_action_form move_metric_down_report_path(report, metric_id: metrics(:one).id)
    assert_action_form move_metric_up_report_path(report, metric_id: metric.id)
    assert_sort_forms sort_alerts_report_path(report)
    assert_sort_forms sort_metrics_report_path(report)
    assert_no_turbo_method_links
  end

  test "nav logout is a DELETE form" do
    get remembers_path
    assert_action_form logout_path, method: "delete"
  end

  # These send exactly what a browser sends when it submits one of these forms
  # without any JavaScript: a POST with a _method override.
  test "submitting the float form without JavaScript floats the remember" do
    remember = remembers(:pinned_remember)
    post float_remember_path(remember), params: { _method: "patch" }
    assert_response :redirect
    assert_equal "floating", remember.reload.state
  end

  test "submitting the logout form without JavaScript logs out" do
    post logout_path, params: { _method: "delete" }
    assert_response :redirect
    get remembers_path
    assert_redirected_to login_path
  end

  private

  def assert_action_form(path, method: "patch", confirm: nil)
    selector = "form.action-button-form[method=post][action=?]"
    assert_select selector, path do |forms|
      forms.each do |form|
        assert_select form, "input[type=hidden][name=_method][value=?]", method
        assert_select form, "button[type=submit]"
        if confirm.is_a?(Regexp)
          assert_match confirm, form["data-turbo-confirm"].to_s
        elsif confirm
          assert_equal confirm, form["data-turbo-confirm"]
        end
      end
    end
  end

  def assert_sort_forms(sort_path)
    %w[name created_at].product(%w[asc desc]).each do |sort_by, direction|
      assert_action_form "#{sort_path}?direction=#{direction}&sort_by=#{sort_by}"
    end
  end

  def assert_no_turbo_method_links
    assert_select "a[data-turbo-method]", 0
  end
end
