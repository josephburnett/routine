module RoutineMcp
  module Tools
    class Arrange < BaseTool
      # relation => [parent type, child type]
      RELATIONS = {
        "form_sections" => %w[form section],
        "section_questions" => %w[section question],
        "report_alerts" => %w[report alert],
        "report_metrics" => %w[report metric]
      }.freeze
      ACTIONS = %w[add remove move_up move_down sort].freeze

      tool_name "arrange"
      description <<~TEXT
        Change what's in a form, section or report, and in what order: sections in a form
        (form_sections), questions in a section (section_questions), alerts or metrics in a
        report (report_alerts, report_metrics). add appends an existing item at the end;
        remove unlinks it (the item itself is kept); move_up/move_down swap it with its
        neighbor; sort reorders everything by name or created_at.
      TEXT
      input_schema(
        properties: {
          relation: { type: "string", enum: RELATIONS.keys },
          parent_id: { type: "integer", description: "The form, section or report" },
          action: { type: "string", enum: ACTIONS },
          child_id: { type: "integer", description: "The section, question, alert or metric (not for sort)" },
          sort_by: { type: "string", enum: Membership::SORT_FIELDS, description: "For sort" },
          direction: { type: "string", enum: %w[asc desc], description: "For sort (default asc)" }
        },
        required: %w[relation parent_id action]
      )
      annotations(**WRITE)

      def self.run(user, relation:, parent_id:, action:, child_id: nil, sort_by: nil, direction: "asc")
        parent_type, child_type = RELATIONS.fetch(relation)
        parent = find!(user, parent_type, parent_id)

        if action == "sort"
          raise ToolError, "sort needs sort_by" if sort_by.blank?

          Membership.sort(relation, parent, sort_by, direction)
        else
          raise ToolError, "#{action} needs child_id" if child_id.nil?

          child = find!(user, child_type, child_id)
          case action
          when "add"
            raise ToolError, "#{child_type.capitalize} #{child.id} is already in this #{parent_type}" unless Membership.add(relation, parent, child)
          when "remove"
            raise ToolError, "#{child_type.capitalize} #{child.id} is not in this #{parent_type}" unless Membership.remove(relation, parent, child)
          when "move_up", "move_down"
            Membership.move(relation, parent, child.id, action == "move_up" ? :up : :down)
          end
        end

        Serialize.detail(parent.reload)
      end
    end
  end
end
