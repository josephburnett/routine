module RoutineMcp
  module Tools
    class TodaysRemembers < BaseTool
      tool_name "todays_remembers"
      description <<~TEXT
        The remembers chosen for today in a namespace and all its children, like the
        remembers display page. Pinned first, then by decay. The daily choice is stable
        for the day.
      TEXT
      input_schema(
        properties: { namespace: { type: "string", description: "Namespace path; omit or \"\" for all" } }
      )
      annotations(**READ_ONLY)

      def self.run(user, namespace: "")
        items = Remember.visible_today_recursive(user, namespace.to_s)
        { namespace: namespace.to_s, date: Date.current.iso8601, remembers: items.map { |r| Serialize.remember(r) } }
      end
    end
  end
end
