require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    login_as_user_one
  end
  test "should get index" do
    get reports_path
    assert_response :success
  end

  test "should get show" do
    get report_path(reports(:one))
    assert_response :success
  end

  test "should get new" do
    get new_report_path
    assert_response :success
  end

  test "should get create" do
    post reports_path, params: {
      report: { name: "Test Report", time_of_day: "09:00", interval_type: "weekly" },
      interval_config: { days: [ "monday" ] }
    }
    assert_response :redirect
  end

  test "should get edit" do
    get edit_report_path(reports(:one))
    assert_response :success
  end

  test "should get update" do
    patch report_path(reports(:one)), params: { report: { name: "Updated Report", time_of_day: "10:00", interval_type: "weekly", interval_config: { days: [ "tuesday" ] } } }
    assert_response :redirect
  end

  test "should get soft_delete" do
    patch soft_delete_report_path(reports(:one))
    assert_response :redirect
  end

  # Tests for remember_namespace functionality
  test "report with remember_namespace set to nil should not show remembers" do
    user = users(:one)

    # Create remembers in root namespace
    remember1 = Remember.create!(description: "Root Remember XYZ123", user: user, namespace: "", state: "floating", decay: 1.0)

    # Create report with remember_namespace = nil (None selected)
    report = Report.create!(
      name: "Test Report",
      user: user,
      interval_type: "none",
      remember_namespace: nil
    )

    get report_path(report)
    assert_response :success

    # Check that response doesn't contain the remember description
    assert_not_includes response.body, "Root Remember XYZ123"
    assert_not_includes response.body, "Remembers from"
  end

  test "report with remember_namespace set to empty string should show all remembers recursively" do
    user = users(:one)

    # Create remembers in root namespace (namespace = "")
    remember1 = Remember.create!(description: "Root Remember ABC111", user: user, namespace: "", state: "floating", decay: 1.0)
    remember2 = Remember.create!(description: "Root Remember ABC222", user: user, namespace: "", state: "floating", decay: 1.0)

    # Create remembers in other namespace (should ALSO appear - Root shows everything recursively)
    remember3 = Remember.create!(description: "Work Remember ABC333", user: user, namespace: "work", state: "floating", decay: 1.0)

    # Create report with remember_namespace = "" (Root selected)
    report = Report.create!(
      name: "Test Report",
      user: user,
      interval_type: "none",
      remember_namespace: ""
    )

    get report_path(report)
    assert_response :success

    # Root namespace shows ALL remembers (root and all children)
    assert_includes response.body, "Root Remember ABC111"
    assert_includes response.body, "Root Remember ABC222"
    assert_includes response.body, "Work Remember ABC333"
    assert_includes response.body, "Remembers from Root"
  end

  test "report with remember_namespace set to specific namespace should show those remembers" do
    user = users(:one)

    # Create remembers in work namespace
    remember1 = Remember.create!(description: "Work Remember DEF444", user: user, namespace: "work", state: "floating", decay: 1.0)

    # Create remembers in work.projects sub-namespace (should also appear)
    remember2 = Remember.create!(description: "Work Project Remember DEF555", user: user, namespace: "work.projects", state: "floating", decay: 1.0)

    # Create remembers in root namespace (should not appear)
    remember3 = Remember.create!(description: "Root Remember DEF666", user: user, namespace: "", state: "floating", decay: 1.0)

    # Create report with remember_namespace = "work"
    report = Report.create!(
      name: "Test Report",
      user: user,
      interval_type: "none",
      remember_namespace: "work"
    )

    get report_path(report)
    assert_response :success

    # Check that response includes work and sub-namespace remembers but not root
    assert_includes response.body, "Work Remember DEF444"
    assert_includes response.body, "Work Project Remember DEF555"
    assert_not_includes response.body, "Root Remember DEF666"
    assert_includes response.body, "Remembers from work"
  end

  test "report should only show remembers with visible_today true based on decay" do
    user = users(:one)

    # Create remember with high decay (will be visible)
    remember_visible = Remember.create!(description: "Visible Remember GHI777", user: user, namespace: "", state: "floating", decay: 1.0)

    # Create remember with zero decay (will not be visible)
    remember_invisible = Remember.create!(description: "Invisible Remember GHI888", user: user, namespace: "", state: "floating", decay: 0.0)

    # Create report with remember_namespace = ""
    report = Report.create!(
      name: "Test Report",
      user: user,
      interval_type: "none",
      remember_namespace: ""
    )

    get report_path(report)
    assert_response :success

    # visible_today_recursive should filter based on decay
    # The visible remember should appear, invisible should not
    assert_includes response.body, "Visible Remember GHI777"
    assert_not_includes response.body, "Invisible Remember GHI888"
  end

  test "report should handle edge case of namespace literally called root" do
    user = users(:one)

    # Create remember in root namespace (namespace = "")
    remember_in_root = Remember.create!(description: "In Root JKL999", user: user, namespace: "", state: "floating", decay: 1.0)

    # Create remember in namespace literally called "root"
    remember_in_root_namespace = Remember.create!(description: "In root namespace JKL000", user: user, namespace: "root", state: "floating", decay: 1.0)

    # Create report selecting Root (empty string) - shows ALL recursively
    report_root = Report.create!(
      name: "Root Report",
      user: user,
      interval_type: "none",
      remember_namespace: ""
    )

    get report_path(report_root)
    assert_response :success

    # Root namespace shows ALL remembers (including "root" namespace as a child)
    assert_includes response.body, "In Root JKL999"
    assert_includes response.body, "In root namespace JKL000"

    # Create report selecting "root" namespace (the string "root")
    report_root_ns = Report.create!(
      name: "root Namespace Report",
      user: user,
      interval_type: "none",
      remember_namespace: "root"
    )

    get report_path(report_root_ns)
    assert_response :success

    # "root" namespace should show only "root" and its children, not actual Root ("")
    assert_includes response.body, "In root namespace JKL000"
    assert_not_includes response.body, "In Root JKL999"
  end

  test "creating report with remember_namespace should save correctly" do
    user = users(:one)

    # Test creating with nil
    post reports_path, params: {
      report: {
        name: "Test Report No Remembers",
        interval_type: "none",
        remember_namespace: nil
      }
    }
    report = Report.last
    assert_nil report.remember_namespace

    # Test creating with empty string (Root)
    post reports_path, params: {
      report: {
        name: "Test Report Root",
        interval_type: "none",
        remember_namespace: ""
      }
    }
    report = Report.last
    assert_equal "", report.remember_namespace

    # Test creating with specific namespace
    post reports_path, params: {
      report: {
        name: "Test Report Work",
        interval_type: "none",
        remember_namespace: "work"
      }
    }
    report = Report.last
    assert_equal "work", report.remember_namespace
  end
end
