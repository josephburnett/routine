module RoutineMcp
  module Tools
    class SaveMetric < BaseTool
      tool_name "save_metric"
      description <<~TEXT
        Create a metric, or update one when id is given (only the fields you pass change).
        A metric turns answers into a time series. Sources: question_ids (answers to these
        questions) and/or child_metric_ids (other metrics). function: answer (raw values),
        sum, average, difference (first_metric_id minus the others), count.
        resolution: bucket size. width: how far back it looks. wrap: fold time into one
        hour/day/week to see patterns. fill: how to fill empty buckets. scale multiplies
        values. Passing question_ids or child_metric_ids replaces that list.
      TEXT
      input_schema(
        properties: {
          id: { type: "integer", description: "Omit to create" },
          name: { type: "string" },
          function: { type: "string", enum: %w[answer sum average difference count] },
          resolution: { type: "string", enum: %w[five_minute hour day week month] },
          width: { type: "string", enum: %w[daily weekly monthly 90_days yearly 7_days 30_days all_time] },
          wrap: { type: "string", enum: %w[none hour day weekly] },
          fill: { type: "string", enum: %w[none zero linear previous] },
          scale: { type: "number", exclusiveMinimum: 0 },
          first_metric_id: { type: "integer", description: "For difference: the metric the others are subtracted from" },
          question_ids: { type: "array", items: { type: "integer" } },
          child_metric_ids: { type: "array", items: { type: "integer" } },
          namespace: { type: "string" }
        }
      )
      annotations(**WRITE)

      FIELDS = %i[name function resolution width wrap fill scale namespace].freeze

      def self.run(user, id: nil, **args)
        metric = id ? find!(user, "metric", id) : user.metrics.build
        metric.assign_attributes(given(args, *FIELDS))

        if args.key?(:first_metric_id)
          metric.first_metric_id = args[:first_metric_id] && find!(user, "metric", args[:first_metric_id]).id
        end
        metric.question_ids = owned_ids!(user, "question", args[:question_ids]) if args.key?(:question_ids)
        if args.key?(:child_metric_ids)
          ids = owned_ids!(user, "metric", args[:child_metric_ids])
          raise ToolError, "A metric can't include itself" if metric.id && ids.include?(metric.id)

          metric.child_metric_ids = ids
        end

        Serialize.detail(save!(metric))
      end

      def self.owned_ids!(user, type, ids)
        ids = Array(ids).uniq
        found = scope_for(user, type).not_deleted.where(id: ids).pluck(:id)
        missing = ids - found
        raise ToolError, "Not found: #{type} #{missing.join(', ')}" if missing.any?

        ids
      end
    end
  end
end
