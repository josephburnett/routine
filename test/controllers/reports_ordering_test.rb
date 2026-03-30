require "test_helper"

class ReportsOrderingTest < ActionDispatch::IntegrationTest
  setup do
    login_as_user_one
    @user = users(:one)
    @report = reports(:one)
  end

  test "should get index with sort params" do
    get reports_path(sort: "name", dir: "asc")
    assert_response :success
  end

  test "move_alert_up swaps positions" do
    @report.report_alerts.destroy_all
    a1 = Alert.create!(name: "A1 #{SecureRandom.hex(4)}", metric: metrics(:one), threshold: 5, direction: "above", user: @user)
    a2 = Alert.create!(name: "A2 #{SecureRandom.hex(4)}", metric: metrics(:one), threshold: 10, direction: "above", user: @user)
    ReportAlert.create!(report: @report, alert: a1, position: 0)
    ReportAlert.create!(report: @report, alert: a2, position: 1)

    patch move_alert_up_report_path(@report), params: { alert_id: a2.id }
    assert_redirected_to report_path(@report)

    assert_equal 1, ReportAlert.find_by(report: @report, alert: a1).position
    assert_equal 0, ReportAlert.find_by(report: @report, alert: a2).position
  end

  test "move_metric_down swaps positions" do
    @report.report_metrics.destroy_all
    m1 = Metric.create!(name: "M1 #{SecureRandom.hex(4)}", user: @user, resolution: "hour", width: "daily", function: "count")
    m2 = Metric.create!(name: "M2 #{SecureRandom.hex(4)}", user: @user, resolution: "hour", width: "daily", function: "count")
    ReportMetric.create!(report: @report, metric: m1, position: 0)
    ReportMetric.create!(report: @report, metric: m2, position: 1)

    patch move_metric_down_report_path(@report), params: { metric_id: m1.id }
    assert_redirected_to report_path(@report)

    assert_equal 1, ReportMetric.find_by(report: @report, metric: m1).position
    assert_equal 0, ReportMetric.find_by(report: @report, metric: m2).position
  end

  test "sort_alerts reorders by name" do
    @report.report_alerts.destroy_all
    a_z = Alert.create!(name: "Zebra #{SecureRandom.hex(4)}", metric: metrics(:one), threshold: 5, direction: "above", user: @user)
    a_a = Alert.create!(name: "Alpha #{SecureRandom.hex(4)}", metric: metrics(:one), threshold: 10, direction: "above", user: @user)
    ReportAlert.create!(report: @report, alert: a_z, position: 0)
    ReportAlert.create!(report: @report, alert: a_a, position: 1)

    patch sort_alerts_report_path(@report), params: { sort_by: "name", direction: "asc" }
    assert_redirected_to report_path(@report)

    assert_equal 0, ReportAlert.find_by(report: @report, alert: a_a).position
    assert_equal 1, ReportAlert.find_by(report: @report, alert: a_z).position
  end

  test "creating report assigns positions to alerts and metrics" do
    metric = Metric.create!(name: "Pos M #{SecureRandom.hex(4)}", user: @user, resolution: "hour", width: "daily", function: "count")
    alert = Alert.create!(name: "Pos A #{SecureRandom.hex(4)}", metric: metric, threshold: 5, direction: "above", user: @user)

    post reports_path, params: {
      report: {
        name: "Test Report #{SecureRandom.hex(4)}",
        interval_type: "none"
      },
      alert_ids: [ alert.id ],
      metric_ids: [ metric.id ]
    }

    report = Report.last
    assert_equal 0, ReportAlert.find_by(report: report, alert: alert).position
    assert_equal 0, ReportMetric.find_by(report: report, metric: metric).position
  end
end
