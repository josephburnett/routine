module RoutineMcp
  module Tools
    class RefreshMetricCache < BaseTool
      tool_name "refresh_metric_cache"
      description <<~TEXT
        Recalculate a metric from scratch, like its Refresh Cache button: drops its cached
        series and the cached status of its alerts. Normally not needed; caches refresh
        themselves when data changes or after an hour.
      TEXT
      input_schema(properties: { metric_id: { type: "integer" } }, required: [ "metric_id" ])
      annotations(**IDEMPOTENT_WRITE)

      def self.run(user, metric_id:)
        metric = find!(user, "metric", metric_id)
        metric.refresh_cache!
        { refreshed: Serialize.metric(metric) }
      end
    end
  end
end
