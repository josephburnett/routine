require "test_helper"
require_relative "mcp_test_helper"

class McpBuildToolsTest < ActionDispatch::IntegrationTest
  include McpTestHelper

  setup do
    @user = users(:one)
  end

  test "save_form creates and renames a form" do
    created = tool_ok("save_form", { name: "Evening", namespace: "health" })
    assert_equal [ "Evening", "health" ], [ created["name"], created["namespace"] ]

    tool_ok("save_form", { id: created["id"], name: "Evening check-in" })
    form = Form.find(created["id"])
    assert_equal [ "Evening check-in", "health" ], [ form.name, form.namespace ]
  end

  test "save_form reports validation errors" do
    assert_match "Name can't be blank", tool_error("save_form", { namespace: "x" })
  end

  test "save_section with form_id joins the form and takes its namespace" do
    form = Form.create!(user: @user, name: "F", namespace: "home")
    first = tool_ok("save_section", { name: "First", namespace: "ignored", form_id: form.id })
    second = tool_ok("save_section", { name: "Second", form_id: form.id })

    assert_equal "home", Section.find(first["id"]).namespace
    assert_equal [ first["id"], second["id"] ], form.reload.sections.map(&:id)
  end

  test "save_section updates and refuses form_id on update" do
    section = sections(:one)
    tool_ok("save_section", { id: section.id, prompt: "How was it?" })
    assert_equal "How was it?", section.reload.prompt
    assert_match "only applies when creating", tool_error("save_section", { id: section.id, form_id: forms(:one).id })
  end

  test "save_question with section_id joins the section and takes its namespace" do
    section = Section.create!(user: @user, name: "S", namespace: "fitness")
    result = tool_ok("save_question", { name: "Energy", question_type: "range", range_min: 1, range_max: 10, section_id: section.id })

    question = Question.find(result["id"])
    assert_equal [ "fitness", 1.0, 10.0 ], [ question.namespace, question.range_min, question.range_max ]
    assert_equal [ question ], section.reload.questions.to_a
  end

  test "save_question enforces the model's rules" do
    assert_match "Range max must be greater than", tool_error("save_question", { name: "Bad", question_type: "range", range_min: 5, range_max: 1 })
  end

  test "save_metric links questions and child metrics" do
    question = questions(:one)
    child = metrics(:one)
    result = tool_ok("save_metric", {
      name: "Combined", function: "sum", resolution: "day", width: "30_days",
      question_ids: [ question.id ], child_metric_ids: [ child.id ]
    })

    metric = Metric.find(result["id"])
    assert_equal [ question.id ], metric.questions.pluck(:id)
    assert_equal [ child.id ], metric.child_metric_ids
    assert_equal "sum", metric.function
  end

  test "save_metric won't link other users' questions or metrics" do
    theirs = Question.create!(user: users(:two), name: "Theirs", question_type: "number")
    assert_match "Not found: question", tool_error("save_metric", {
      name: "Sneaky", function: "answer", resolution: "day", width: "daily", question_ids: [ theirs.id ]
    })
    assert_match "Not found: metric", tool_error("save_metric", {
      name: "Sneaky", function: "answer", resolution: "day", width: "daily", child_metric_ids: [ metrics(:two).id ]
    })
  end

  test "save_metric updates only the given fields" do
    metric = metrics(:one)
    tool_ok("save_metric", { id: metric.id, width: "90_days" })
    metric.reload
    assert_equal [ "90_days", "hour", "Test Metric One" ], [ metric.width, metric.resolution, metric.name ]
  end

  test "save_alert creates an alert on one of the user's metrics" do
    result = tool_ok("save_alert", { name: "Too warm", metric_id: metrics(:one).id, threshold: 85, direction: "above", delay: 2 })
    alert = Alert.find(result["id"])
    assert_equal [ 85.0, "above", 2, metrics(:one) ], [ alert.threshold.to_f, alert.direction, alert.delay, alert.metric ]
    assert_includes %w[activated deactivated], result["status"]

    assert_match "Not found", tool_error("save_alert", { name: "X", metric_id: metrics(:two).id, threshold: 1, direction: "above" })
  end

  test "save_report builds the schedule and contents like the report form" do
    alert2 = Alert.create!(user: @user, name: "Second", metric: metrics(:one), threshold: 1, direction: "below")
    result = tool_ok("save_report", {
      name: "Weekly", interval_type: "weekly", interval_config: { days: [ "monday", "friday" ] },
      time_of_day: "08:30", remember_namespace: "", alert_ids: [ alert2.id, alerts(:one).id ], metric_ids: [ metrics(:one).id ]
    })

    report = Report.find(result["id"])
    assert_equal({ "days" => %w[monday friday] }, report.interval_config)
    assert_equal "08:30", report.time_of_day.strftime("%H:%M")
    assert_equal "", report.remember_namespace
    assert_equal [ alert2.id, alerts(:one).id ], report.report_alerts.order(:position).pluck(:alert_id)
    assert_equal [ metrics(:one).id ], report.report_metrics.pluck(:metric_id)
  end

  test "save_report update keeps contents unless lists are given" do
    report = reports(:one)
    alert_ids = report.report_alerts.pluck(:alert_id)

    tool_ok("save_report", { id: report.id, name: "Renamed", remember_namespace: nil })
    report.reload
    assert_equal "Renamed", report.name
    assert_nil report.remember_namespace
    assert_equal alert_ids, report.report_alerts.pluck(:alert_id)

    tool_ok("save_report", { id: report.id, alert_ids: [] })
    assert_empty report.reload.report_alerts
  end

  test "save_report switches to monthly" do
    report = reports(:one)
    tool_ok("save_report", { id: report.id, interval_type: "monthly", interval_config: { day_of_month: 15 } })
    assert_equal({ "day_of_month" => 15 }, report.reload.interval_config)
  end

  test "save_report rejects other users' alerts" do
    assert_match "Not found: alert", tool_error("save_report", {
      name: "X", interval_type: "none", alert_ids: [ alerts(:two).id ]
    })
  end

  test "arrange adds, moves, sorts and removes children" do
    form = Form.create!(user: @user, name: "Arranged")
    zebra = Section.create!(user: @user, name: "Zebra")
    apple = Section.create!(user: @user, name: "Apple")

    tool_ok("arrange", { relation: "form_sections", parent_id: form.id, action: "add", child_id: zebra.id })
    result = tool_ok("arrange", { relation: "form_sections", parent_id: form.id, action: "add", child_id: apple.id })
    assert_equal %w[Zebra Apple], result["sections"].map { |s| s["name"] }

    assert_match "already in", tool_error("arrange", { relation: "form_sections", parent_id: form.id, action: "add", child_id: apple.id })

    moved = tool_ok("arrange", { relation: "form_sections", parent_id: form.id, action: "move_up", child_id: apple.id })
    assert_equal %w[Apple Zebra], moved["sections"].map { |s| s["name"] }

    sorted = tool_ok("arrange", { relation: "form_sections", parent_id: form.id, action: "sort", sort_by: "name", direction: "desc" })
    assert_equal %w[Zebra Apple], sorted["sections"].map { |s| s["name"] }

    removed = tool_ok("arrange", { relation: "form_sections", parent_id: form.id, action: "remove", child_id: zebra.id })
    assert_equal %w[Apple], removed["sections"].map { |s| s["name"] }
    assert Section.exists?(zebra.id), "remove only unlinks"
  end

  test "arrange works for section questions and report contents" do
    section = Section.create!(user: @user, name: "S")
    q = Question.create!(user: @user, name: "Q", question_type: "number")
    tool_ok("arrange", { relation: "section_questions", parent_id: section.id, action: "add", child_id: q.id })
    assert_equal [ q ], section.reload.questions.to_a

    report = reports(:one)
    metric = Metric.create!(user: @user, name: "Extra", function: "answer", resolution: "day", width: "daily")
    result = tool_ok("arrange", { relation: "report_metrics", parent_id: report.id, action: "add", child_id: metric.id })
    assert_equal metric.id, result["metrics"].last["id"]
  end

  test "arrange checks ownership and arguments" do
    form = Form.create!(user: @user, name: "Mine")
    assert_match "Not found", tool_error("arrange", { relation: "form_sections", parent_id: form.id, action: "add", child_id: sections(:two).id })
    assert_match "needs child_id", tool_error("arrange", { relation: "form_sections", parent_id: form.id, action: "remove" })
    assert_match "sort needs sort_by", tool_error("arrange", { relation: "form_sections", parent_id: form.id, action: "sort" })
  end

  test "move_to_namespace cascades like the namespaces page" do
    form = Form.create!(user: @user, name: "Mover", namespace: "old")
    section = Section.create!(user: @user, name: "Inner", namespace: "old")
    question = Question.create!(user: @user, name: "Deep", question_type: "number", namespace: "old")
    FormSection.create!(form: form, section: section, position: 0)
    SectionQuestion.create!(section: section, question: question, position: 0)
    response = SurveySubmission.call(form: form, user: @user, answers: { question.id => "1" })

    result = tool_ok("move_to_namespace", { items: { forms: [ form.id ] }, target_namespace: "new" })

    assert_equal 6, result["moved"] # form, response, its answer, section, question, the answer again via question
    [ form, section, question, response, response.answers.first ].each { |r| assert_equal "new", r.reload.namespace }
  end

  test "move_to_namespace without cascade moves only the item" do
    form = Form.create!(user: @user, name: "Solo", namespace: "old")
    section = Section.create!(user: @user, name: "Stays", namespace: "old")
    FormSection.create!(form: form, section: section, position: 0)

    assert_equal 1, tool_ok("move_to_namespace", { items: { forms: [ form.id ] }, target_namespace: "new", cascade: false })["moved"]
    assert_equal "old", section.reload.namespace
  end

  test "move_to_namespace refuses other users' items" do
    assert_match "Not found", tool_error("move_to_namespace", { items: { forms: [ forms(:two).id ] }, target_namespace: "mine" })
    assert_equal "", forms(:two).reload.namespace
  end

  test "delete_item soft-deletes, and a response takes its answers" do
    response = responses(:one)
    answer_ids = response.answers.pluck(:id)

    tool_ok("delete_item", { type: "response", id: response.id })
    assert response.reload.deleted
    assert Answer.where(id: answer_ids).all?(&:deleted)
    assert_match "Not found", tool_error("get_item", { type: "response", id: response.id })
  end

  test "refresh_metric_cache drops the cached series" do
    metric = metrics(:one)
    MetricSeriesCache.update_for_metric(metric)
    assert metric.reload.metric_series_cache

    tool_ok("refresh_metric_cache", { metric_id: metric.id })
    assert_nil metric.reload.metric_series_cache
  end

  test "send_report_now emails a report with content" do
    report = reports(:one)
    assert_emails 1 do
      result = tool_ok("send_report_now", { report_id: report.id })
      assert result["sent"]
    end
    assert report.reload.last_sent_at > 1.minute.ago
  end

  test "send_report_now refuses an empty report" do
    empty = Report.create!(user: @user, name: "Empty", interval_type: "none")
    assert_no_emails do
      assert_match "no content to send", tool_error("send_report_now", { report_id: empty.id })
    end
  end
end
