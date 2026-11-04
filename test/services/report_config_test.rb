require "test_helper"

class ReportConfigTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @report = reports(:one)
  end

  test "builds weekly and monthly schedules like the report form" do
    ReportConfig.apply_interval_config(@report, "weekly", { "days" => [ "monday", "" ] })
    assert_equal({ "days" => [ "monday" ] }, @report.interval_config)

    ReportConfig.apply_interval_config(@report, "weekly", { "other" => "x" })
    assert_equal({ "days" => [] }, @report.interval_config)

    ReportConfig.apply_interval_config(@report, "monthly", { "day_of_month" => "15" })
    assert_equal({ "day_of_month" => 15 }, @report.interval_config)

    ReportConfig.apply_interval_config(@report, "weekly", nil)
    assert_equal({}, @report.interval_config)
  end

  test "replaces contents in order with the user's own items only" do
    mine = Alert.create!(user: @user, name: "Mine", metric: metrics(:one), threshold: 1, direction: "above")
    ReportConfig.replace_contents(@report, user: @user, alert_ids: [ mine.id, alerts(:two).id, alerts(:one).id ])
    assert_equal [ mine.id, alerts(:one).id ], @report.report_alerts.order(:position).pluck(:alert_id)
  end

  test "nil leaves a list unchanged" do
    metric_ids = @report.report_metrics.pluck(:metric_id)
    ReportConfig.replace_contents(@report, user: @user, alert_ids: [])
    assert_equal metric_ids, @report.report_metrics.pluck(:metric_id)
    assert_empty @report.report_alerts
  end
end
