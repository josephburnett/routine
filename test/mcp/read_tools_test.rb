require "test_helper"
require_relative "mcp_test_helper"

class McpReadToolsTest < ActionDispatch::IntegrationTest
  include McpTestHelper

  setup do
    @user = users(:one)
  end

  test "browse_namespace shows child namespaces and items like the namespaces page" do
    Form.create!(user: @user, name: "Pool log", namespace: "home.pool")
    Remember.create!(user: @user, description: "Check chlorine", namespace: "home")

    root = tool_ok("browse_namespace")
    assert_includes root["child_namespaces"], "home"
    assert_nil root["parent_namespace"]

    home = tool_ok("browse_namespace", { namespace: "home" })
    assert_equal "home", home["namespace"]
    assert_equal "", home["parent_namespace"]
    assert_equal [ "home.pool" ], home["child_namespaces"]
    assert_equal [ "Check chlorine" ], home["items"]["remembers"].map { |r| r["description"] }

    pool = tool_ok("browse_namespace", { namespace: "home.pool" })
    assert_equal [ "Pool log" ], pool["items"]["forms"].map { |f| f["name"] }
  end

  test "browse_namespace hides answers and sections inside forms, as the page does" do
    root = tool_ok("browse_namespace", { namespace: "" })
    refute root["items"].key?("answers")
    refute root["items"].key?("responses")
    refute_includes Array(root["items"]["sections"]).map { |s| s["id"] }, sections(:one).id
  end

  test "list_items lists one type across namespaces" do
    Question.create!(user: @user, name: "Swim laps", question_type: "number", namespace: "fitness.swim")
    result = tool_ok("list_items", { type: "question" })

    names = result["items"].map { |q| q["name"] }
    assert_includes names, "Swim laps"
    assert_includes names, questions(:one).name
    assert_equal result["items"].size, result["total"]
  end

  test "list_items filters by namespace, recursively, and by name" do
    Question.create!(user: @user, name: "Swim laps", question_type: "number", namespace: "fitness.swim")
    Question.create!(user: @user, name: "Run miles", question_type: "number", namespace: "fitness")

    direct = tool_ok("list_items", { type: "question", namespace: "fitness" })
    assert_equal [ "Run miles" ], direct["items"].map { |q| q["name"] }

    recursive = tool_ok("list_items", { type: "question", namespace: "fitness", recursive: true })
    assert_equal [ "Run miles", "Swim laps" ].sort, recursive["items"].map { |q| q["name"] }.sort

    found = tool_ok("list_items", { type: "question", query: "swim" })
    assert_equal [ "Swim laps" ], found["items"].map { |q| q["name"] }
  end

  test "list_items treats query wildcards literally" do
    Question.create!(user: @user, name: "100% effort", question_type: "number")
    Question.create!(user: @user, name: "Effort", question_type: "number")
    found = tool_ok("list_items", { type: "question", query: "%" })
    assert_equal [ "100% effort" ], found["items"].map { |q| q["name"] }
  end

  test "list_items shows newest answers first and filters by question and time" do
    question = questions(:one)
    old = Answer.create!(user: @user, question: question, answer_type: "number", number_value: 1, created_at: 3.days.ago)
    recent = Answer.create!(user: @user, question: question, answer_type: "number", number_value: 2, created_at: 1.hour.ago)

    result = tool_ok("list_items", { type: "answer", question_id: question.id })
    ids = result["items"].map { |a| a["id"] }
    assert ids.index(recent.id) < ids.index(old.id)

    since = tool_ok("list_items", { type: "answer", question_id: question.id, since: 2.days.ago.iso8601 })
    assert_includes since["items"].map { |a| a["id"] }, recent.id
    refute_includes since["items"].map { |a| a["id"] }, old.id

    before = tool_ok("list_items", { type: "answer", question_id: question.id, before: 2.days.ago.iso8601 })
    assert_equal [ old.id ], before["items"].map { |a| a["id"] }
  end

  test "list_items pages with limit and offset" do
    3.times { |i| Remember.create!(user: @user, description: "Page #{i}", namespace: "paging") }
    first = tool_ok("list_items", { type: "remember", namespace: "paging", limit: 2 })
    second = tool_ok("list_items", { type: "remember", namespace: "paging", limit: 2, offset: 2 })

    assert_equal 3, first["total"]
    assert_equal 2, first["items"].size
    assert_equal 1, second["items"].size
  end

  test "list_items only shows the user's own, undeleted items" do
    Question.create!(user: users(:two), name: "Someone else's", question_type: "number")
    Question.create!(user: @user, name: "Deleted one", question_type: "number", deleted: true)

    names = tool_ok("list_items", { type: "question" })["items"].map { |q| q["name"] }
    refute_includes names, "Someone else's"
    refute_includes names, "Deleted one"
  end

  test "list_items rejects a name query for types without names" do
    assert_match "query only works", tool_error("list_items", { type: "answer", query: "x" })
  end

  test "get_item returns a form with its sections and questions" do
    form = tool_ok("get_item", { type: "form", id: forms(:one).id })
    assert_equal forms(:one).name, form["name"]
    section = form["sections"].find { |s| s["id"] == sections(:one).id }
    assert section
    assert_includes section["questions"].map { |q| q["id"] }, questions(:one).id
  end

  test "get_item returns details for every type" do
    report = reports(:one)
    {
      "section" => sections(:one), "question" => questions(:one), "answer" => answers(:one),
      "response" => responses(:one), "metric" => metrics(:one), "alert" => alerts(:one),
      "report" => report, "remember" => remembers(:floating_high)
    }.each do |type, record|
      item = tool_ok("get_item", { type: type, id: record.id })
      assert_equal type, item["type"]
      assert_equal record.id, item["id"]
    end
  end

  test "get_item includes alert status" do
    alert = tool_ok("get_item", { type: "alert", id: alerts(:one).id })
    assert_includes %w[activated deactivated disabled], alert["status"]
    assert alert.key?("activation_progress")
  end

  test "get_item can't see other users' items or deleted items" do
    assert_match "Not found", tool_error("get_item", { type: "form", id: forms(:two).id })
    forms(:one).soft_delete!
    assert_match "Not found", tool_error("get_item", { type: "form", id: forms(:one).id })
  end

  test "get_metric_series returns points oldest first" do
    question = questions(:one)
    [ 3, 2, 1 ].each do |days|
      Answer.create!(user: @user, question: question, answer_type: "number", number_value: days, created_at: days.days.ago)
    end
    metric = Metric.create!(user: @user, name: "Daily", function: "answer", resolution: "day", width: "all_time")
    MetricQuestion.create!(metric: metric, question: question)

    result = tool_ok("get_metric_series", { metric_id: metric.id, all: true })
    assert_equal "Daily", result["metric"]["name"]
    times = result["points"].map { |p| Time.zone.parse(p["at"]) }
    assert_equal times.sort, times
    assert result["points"].any? { |p| p["value"] == 3 }

    last_two = tool_ok("get_metric_series", { metric_id: metric.id, last: 2 })
    assert_equal 2, last_two["points"].size
  end

  test "todays_remembers matches the display page" do
    Remember.create!(user: @user, description: "Always today", namespace: "deck", state: "pinned", decay: 1.0)
    Remember.create!(user: @user, description: "Retired", namespace: "deck", state: "retired", decay: 0.0)

    result = tool_ok("todays_remembers", { namespace: "deck" })
    assert_equal Date.current.iso8601, result["date"]
    assert_equal [ "Always today" ], result["remembers"].map { |r| r["description"] }
    assert_equal Remember.visible_today_recursive(@user, "").map(&:id),
                 tool_ok("todays_remembers")["remembers"].map { |r| r["id"] }
  end
end
