module RoutineMcp
  module Tools
    class ListItems < BaseTool
      MAX_LIMIT = 200
      SORTS = %w[name description created_at updated_at].freeze
      NAME_COLUMN = { "remember" => "description" }.freeze
      NAMED_TYPES = %w[form section question metric alert report remember].freeze

      tool_name "list_items"
      description <<~TEXT
        List the user's items of one type, with filters. Without namespace it searches all
        namespaces; with namespace it shows items directly in that namespace, or in it and
        all its children with recursive: true. Answers and responses default to newest
        first, remembers to highest decay first, everything else to creation order.
        Returns { items, total, limit, offset }.
      TEXT
      input_schema(
        properties: {
          type: { type: "string", enum: TYPES.keys },
          namespace: { type: "string", description: "Namespace path; \"\" is the root" },
          recursive: { type: "boolean", description: "Include child namespaces (default false)" },
          query: { type: "string", description: "Case-insensitive text to find in the name (description for remembers)" },
          question_id: { type: "integer", description: "Answers: only for this question" },
          response_id: { type: "integer", description: "Answers: only in this response" },
          form_id: { type: "integer", description: "Responses: only for this form" },
          state: { type: "string", enum: Remember::STATES, description: "Remembers: only in this state" },
          since: { type: "string", description: "Answers/responses: recorded at or after this time (ISO 8601 or YYYY-MM-DD)" },
          before: { type: "string", description: "Answers/responses: recorded before this time" },
          sort: { type: "string", enum: SORTS },
          direction: { type: "string", enum: %w[asc desc] },
          limit: { type: "integer", minimum: 1, maximum: MAX_LIMIT, description: "Default 50" },
          offset: { type: "integer", minimum: 0 }
        },
        required: [ "type" ]
      )
      annotations(**READ_ONLY)

      def self.run(user, type:, namespace: nil, recursive: false, query: nil, question_id: nil, response_id: nil,
                   form_id: nil, state: nil, since: nil, before: nil, sort: nil, direction: nil, limit: 50, offset: 0)
        scope = scope_for(user, type).not_deleted
        scope = filter_namespace(scope, namespace, recursive) unless namespace.nil?

        if query.present?
          raise ToolError, "query only works for #{NAMED_TYPES.join(', ')}" unless NAMED_TYPES.include?(type)

          column = NAME_COLUMN.fetch(type, "name")
          scope = scope.where("#{column} LIKE ? ESCAPE '\\'", "%#{ActiveRecord::Base.sanitize_sql_like(query)}%")
        end

        scope = scope.where(question_id: question_id) if question_id && type == "answer"
        scope = scope.where(response_id: response_id) if response_id && type == "answer"
        scope = scope.where(form_id: form_id) if form_id && type == "response"
        scope = scope.where(state: state) if state && type == "remember"
        if %w[answer response].include?(type)
          scope = scope.where(created_at: parse_time!(since)..) if since.present?
          scope = scope.where(created_at: ...parse_time!(before)) if before.present?
        end

        scope = order(scope, type, sort, direction)
        limit = limit.to_i.clamp(1, MAX_LIMIT)
        total = scope.count

        items = scope.limit(limit).offset(offset.to_i)
        items = items.includes(:question) if type == "answer"
        items = items.includes(:form) if type == "response"
        { items: items.map { |i| Serialize.summary(i) }, total: total, limit: limit, offset: offset.to_i }
      end

      def self.filter_namespace(scope, namespace, recursive)
        namespace = namespace.to_s.strip
        return scope.where(namespace: namespace) unless recursive
        return scope if namespace.empty?

        scope.where("namespace = ? OR namespace LIKE ? ESCAPE '\\'", namespace, "#{ActiveRecord::Base.sanitize_sql_like(namespace)}.%")
      end

      def self.order(scope, type, sort, direction)
        if sort.present?
          column = sort == "name" ? NAME_COLUMN.fetch(type, "name") : sort
          raise ToolError, "Can't sort #{type} by #{sort}" unless scope.model.column_names.include?(column)

          return scope.reorder(column => direction == "desc" ? :desc : :asc)
        end

        case type
        when "answer", "response" then scope.reorder(created_at: :desc)
        when "remember" then scope.sorted_by_decay
        else scope.reorder(:id)
        end
      end
    end
  end
end
