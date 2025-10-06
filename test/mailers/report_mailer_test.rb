require "test_helper"

class ReportMailerTest < ActionMailer::TestCase
  test "scheduled_report" do
    report = reports(:one)
    mail = ReportMailer.scheduled_report(report)
    assert_equal "Routine Report: #{report.name}", mail.subject
    assert_equal [ report.user.email ], mail.to
    assert_equal [ "routine@home.taile52c2f.ts.net" ], mail.from
    assert_match report.name, mail.body.encoded
  end
end
