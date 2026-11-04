module RoutineMcp
  module Tools
    class RememberAction < BaseTool
      ACTIONS = %w[pin float bump_up bump_down retire set_decay].freeze

      tool_name "remember_action"
      description <<~TEXT
        Change how often a remember shows up, like the buttons on its page:
        pin (keep its decay, stop daily decay), float (resume daily decay),
        bump_up (about double the decay, up to 1.0, and float), bump_down (about halve it,
        down to the minimum, and float unless retired), retire (stop showing it),
        set_decay (needs decay; kept between your minimum decay and 1.0).
      TEXT
      input_schema(
        properties: {
          remember_id: { type: "integer" },
          action: { type: "string", enum: ACTIONS },
          decay: { type: "number", description: "For set_decay" }
        },
        required: %w[remember_id action]
      )
      annotations(**WRITE)

      def self.run(user, remember_id:, action:, decay: nil)
        remember = find!(user, "remember", remember_id)

        case action
        when "pin" then remember.pin!
        when "float" then remember.float!
        when "bump_up" then remember.bump_up!
        when "bump_down" then remember.bump_down!
        when "retire" then remember.retire!
        when "set_decay"
          raise ToolError, "set_decay needs decay" if decay.nil?

          remember.set_decay_within_limits!(decay)
        end

        Serialize.remember(remember.reload)
      end
    end
  end
end
