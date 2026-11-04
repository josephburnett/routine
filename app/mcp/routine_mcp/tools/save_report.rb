module RoutineMcp
  module Tools
    class SaveReport < BaseTool
      tool_name "save_report"
      description <<~TEXT
        Create a report, or update one when id is given (only the fields you pass change).
        A report emails its active alerts, its metrics and today's remembers on a schedule.
        interval_type: weekly (interval_config { days: ["monday", ...] }), monthly
        (interval_config { day_of_month: 1-31 }) or none (only sent with send_report_now).
        time_of_day is "HH:MM" in Pacific time. remember_namespace: null for no remembers,
        "" for all, or a namespace. Passing alert_ids or metric_ids replaces that list, in
        that order.
      TEXT
      input_schema(
        properties: {
          id: { type: "integer", description: "Omit to create" },
          name: { type: "string" },
          interval_type: { type: "string", enum: %w[weekly monthly none] },
          interval_config: {
            type: "object",
            properties: {
              days: { type: "array", items: { type: "string", enum: %w[sunday monday tuesday wednesday thursday friday saturday] } },
              day_of_month: { type: "integer", minimum: 1, maximum: 31 }
            }
          },
          time_of_day: { type: "string", pattern: "^\\d{1,2}:\\d{2}$" },
          remember_namespace: { type: [ "string", "null" ] },
          alert_ids: { type: "array", items: { type: "integer" } },
          metric_ids: { type: "array", items: { type: "integer" } },
          namespace: { type: "string" }
        }
      )
      annotations(**WRITE)

      def self.run(user, id: nil, **args)
        report = id ? find!(user, "report", id) : user.reports.build
        report.assign_attributes(given(args, :name, :interval_type, :time_of_day, :namespace, :remember_namespace))
        if args.key?(:interval_config) || args.key?(:interval_type)
          ReportConfig.apply_interval_config(report, report.interval_type, args[:interval_config] || report.interval_config)
        end

        check_owned!(user, "alert", args[:alert_ids])
        check_owned!(user, "metric", args[:metric_ids])

        Report.transaction do
          save!(report)
          ReportConfig.replace_contents(report, user: user, alert_ids: args[:alert_ids], metric_ids: args[:metric_ids])
        end
        Serialize.report(report.reload)
      end

      def self.check_owned!(user, type, ids)
        return if ids.nil?

        missing = ids.uniq - scope_for(user, type).not_deleted.where(id: ids).pluck(:id)
        raise ToolError, "Not found: #{type} #{missing.join(', ')}" if missing.any?
      end
    end
  end
end
