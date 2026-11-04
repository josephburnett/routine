require "test_helper"
require_relative "mcp_test_helper"

class McpEndpointTest < ActionDispatch::IntegrationTest
  include McpTestHelper

  test "rejects requests without a token" do
    mcp_post({ jsonrpc: "2.0", id: 1, method: "tools/list" }, token: nil)
    assert_response :unauthorized
    assert_match "Bearer", response.headers["WWW-Authenticate"]
  end

  test "rejects a wrong token" do
    mcp_post({ jsonrpc: "2.0", id: 1, method: "tools/list" }, token: "rt_not-a-real-token")
    assert_response :unauthorized
  end

  test "rejects a revoked token" do
    token, plain = ApiToken.issue!(user: users(:one), name: "old")
    token.revoke!
    mcp_post({ jsonrpc: "2.0", id: 1, method: "tools/list" }, token: plain)
    assert_response :unauthorized
  end

  test "does not need a browser session or CSRF token" do
    body = mcp("tools/list")
    assert body["result"]["tools"].any?
  end

  test "initialize describes the server" do
    body = mcp("initialize", {
      protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "test", version: "1" }
    })
    result = body["result"]
    assert_equal "routine", result["serverInfo"]["name"]
    assert result["capabilities"].key?("tools")
    assert_match "namespaces", result["instructions"]
  end

  test "lists every tool with a schema and safety hints" do
    tools = mcp("tools/list")["result"]["tools"].index_by { |t| t["name"] }

    assert_equal RoutineMcp::TOOLS.map(&:name_value).sort, tools.keys.sort
    tools.each_value do |tool|
      assert tool["description"].present?, "#{tool['name']} needs a description"
      assert_equal "object", tool["inputSchema"]["type"]
      assert tool["annotations"].key?("readOnlyHint"), "#{tool['name']} needs annotations"
    end

    %w[browse_namespace list_items get_item get_metric_series todays_remembers].each do |name|
      assert tools[name]["annotations"]["readOnlyHint"], "#{name} should be read-only"
    end
    assert tools["delete_item"]["annotations"]["destructiveHint"]
    refute tools["submit_form"]["annotations"]["readOnlyHint"]
  end

  test "does not expose settings, backups or login" do
    names = mcp("tools/list")["result"]["tools"].map { |t| t["name"] }
    assert_empty names.grep(/setting|backup|password|session|token|user/)
  end

  test "notifications get 202 and no body" do
    mcp_post({ jsonrpc: "2.0", method: "notifications/initialized" })
    assert_response :accepted
  end

  test "GET and DELETE are not allowed" do
    get "/mcp", headers: { "Authorization" => "Bearer #{mcp_token}" }
    assert_response :method_not_allowed
    delete "/mcp", headers: { "Authorization" => "Bearer #{mcp_token}" }
    assert_response :method_not_allowed
  end

  test "unknown tools are a JSON-RPC error" do
    body = mcp("tools/call", { name: "no_such_tool", arguments: {} })
    assert body["error"]
  end

  test "schema violations come back as tool errors" do
    error = tool_error("get_item", { type: "spaceship", id: 1 })
    assert_match(/type/, error)
  end

  test "records when a token was used" do
    token, plain = ApiToken.issue!(user: users(:one), name: "fresh")
    assert_nil token.last_used_at
    mcp("tools/list", {}, token: plain)
    assert token.reload.last_used_at
  end
end
