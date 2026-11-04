module RoutineMcp
  # Base for all Routine tools. Subclasses define `run(user, **args)` and return
  # a Hash; it's sent back as JSON text and as structured content. Expected
  # problems (not found, validation) come back as tool errors Claude can read.
  class BaseTool < MCP::Tool
    class ToolError < StandardError; end

    # Item types and the user's association for each
    TYPES = {
      "form" => :forms, "section" => :sections, "question" => :questions,
      "answer" => :answers, "response" => :responses, "metric" => :metrics,
      "alert" => :alerts, "report" => :reports, "remember" => :remembers
    }.freeze

    READ_ONLY = { read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false }.freeze
    WRITE = { read_only_hint: false, destructive_hint: false, idempotent_hint: false, open_world_hint: false }.freeze
    IDEMPOTENT_WRITE = WRITE.merge(idempotent_hint: true).freeze
    DESTRUCTIVE = WRITE.merge(destructive_hint: true).freeze

    class << self
      def call(server_context:, **args)
        user = server_context[:user]
        raise ToolError, "Not authenticated" unless user

        success(run(user, **args))
      rescue ToolError, Membership::Error, NamespaceMove::Error, ResponseUpdate::InvalidDatetime => e
        failure(e.message)
      rescue ActiveRecord::RecordNotFound => e
        failure("Not found: #{e.model&.underscore&.humanize || 'item'} #{e.id}".strip)
      rescue ActiveRecord::RecordInvalid => e
        failure(e.record.errors.full_messages.to_sentence)
      end

      private

      def success(data)
        MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(data) } ], structured_content: data)
      end

      def failure(message)
        MCP::Tool::Response.new([ { type: "text", text: message } ], error: true)
      end

      def scope_for(user, type)
        association = TYPES.fetch(type.to_s) { raise ToolError, "Unknown type: #{type}. Use one of #{TYPES.keys.join(', ')}" }
        user.public_send(association)
      end

      # One of the user's items, not deleted.
      def find!(user, type, id)
        scope_for(user, type).not_deleted.find(id)
      end

      # Raises a ToolError listing the record's validation errors unless it saved.
      def save!(record)
        return record if record.save

        raise ToolError, record.errors.full_messages.to_sentence
      end

      def parse_time!(value)
        return nil if value.blank?

        Time.zone.parse(value.to_s) || raise(ToolError, "Invalid date and time: #{value}")
      rescue ArgumentError
        raise ToolError, "Invalid date and time: #{value}"
      end

      # Only the keys that were passed, so updates leave other fields alone.
      def given(args, *keys)
        args.slice(*keys)
      end
    end
  end
end
