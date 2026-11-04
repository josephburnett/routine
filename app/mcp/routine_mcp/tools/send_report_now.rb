module RoutineMcp
  module Tools
    class SendReportNow < BaseTool
      tool_name "send_report_now"
      description <<~TEXT
        Email a report to the user now, like its Send Report Now button. Fails if the
        report has nothing to send (no active alerts and no metrics).
      TEXT
      input_schema(properties: { report_id: { type: "integer" } }, required: [ "report_id" ])
      annotations(**WRITE.merge(open_world_hint: true))

      def self.run(user, report_id:)
        report = find!(user, "report", report_id)
        ok, message = ReportConfig.send_now(report)
        raise ToolError, message unless ok

        { sent: true, message: message, report: Serialize.report(report) }
      end
    end
  end
end
