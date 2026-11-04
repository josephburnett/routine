module RoutineMcp
  module Tools
    class GetMetricSeries < BaseTool
      tool_name "get_metric_series"
      description <<~TEXT
        Get a metric's time series as [{ at, value }], oldest first. By default it returns
        the points the metric page shows (its width plus a margin); set all: true for the
        whole series, or last: N for the most recent N points.
      TEXT
      input_schema(
        properties: {
          metric_id: { type: "integer" },
          all: { type: "boolean" },
          last: { type: "integer", minimum: 1 }
        },
        required: [ "metric_id" ]
      )
      annotations(**READ_ONLY)

      def self.run(user, metric_id:, all: false, last: nil)
        metric = find!(user, "metric", metric_id)
        series = if last then metric.series.last(last)
        elsif all then metric.series
        else metric.display_series
        end

        { metric: Serialize.metric(metric), points: series.map { |p| Serialize.point(p) } }
      end
    end
  end
end
