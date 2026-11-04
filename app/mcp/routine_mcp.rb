# MCP server for Routine: lets an MCP client (Claude Code) do what the web app
# does, as the user who owns the API token. Settings, backups and login are not
# exposed.
module RoutineMcp
  VERSION = "1.0.0".freeze

  INSTRUCTIONS = <<~TEXT.freeze
    Routine tracks personal routines. Items live in namespaces: dot-separated folders like
    "home.pool" ("" is the root).
    - Forms hold ordered sections, and sections hold ordered questions (string, number, bool,
      or range with a min and max). Submitting a form creates a response with one answer per
      question; questions can also be answered on their own.
    - Metrics turn answers (or other metrics) into time series. Alerts watch a metric against
      a threshold. Reports email active alerts, metrics and today's remembers on a schedule.
    - Remembers are reminders that show up on a given day with a chance set by their decay;
      pinned ones always show at their decay, retired ones never do.
    Times are in the app's time zone (Pacific). Start with browse_namespace or list_items to
    find ids, and get_item to see an item's details before changing it.
  TEXT

  TOOLS = [
    Tools::BrowseNamespace, Tools::ListItems, Tools::GetItem, Tools::GetMetricSeries, Tools::TodaysRemembers,
    Tools::SubmitForm, Tools::AnswerQuestion, Tools::UpdateAnswer, Tools::UpdateResponse,
    Tools::SaveRemember, Tools::RememberAction,
    Tools::SaveForm, Tools::SaveSection, Tools::SaveQuestion, Tools::SaveMetric, Tools::SaveAlert, Tools::SaveReport,
    Tools::Arrange, Tools::MoveToNamespace, Tools::DeleteItem,
    Tools::RefreshMetricCache, Tools::SendReportNow
  ].freeze

  # Unexpected errors inside tools are logged; the client only sees "Internal error".
  CONFIGURATION = MCP::Configuration.new(
    exception_reporter: lambda do |exception, _context|
      Rails.logger.error("MCP error: #{exception.class}: #{exception.message}\n#{Array(exception.backtrace).first(10).join("\n")}")
    end
  )

  def self.server(user)
    MCP::Server.new(
      configuration: CONFIGURATION,
      name: "routine",
      title: "Routine",
      version: VERSION,
      instructions: INSTRUCTIONS,
      tools: TOOLS,
      server_context: { user: user }
    )
  end
end
