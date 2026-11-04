# Sends JSON-RPC messages to /mcp the way an MCP client does.
module McpTestHelper
  def mcp_token(user = users(:one))
    @mcp_tokens ||= {}
    @mcp_tokens[user.id] ||= ApiToken.issue!(user: user, name: "test").last
  end

  def mcp_post(body, token: mcp_token)
    headers = {
      "Content-Type" => "application/json",
      "Accept" => "application/json, text/event-stream"
    }
    headers["Authorization"] = "Bearer #{token}" if token
    post "/mcp", params: body.to_json, headers: headers
  end

  def mcp(method, params = {}, token: mcp_token)
    mcp_post({ jsonrpc: "2.0", id: 1, method: method, params: params }, token: token)
    assert_response :success
    JSON.parse(response.body)
  end

  def call_tool(name, arguments = {}, token: mcp_token)
    body = mcp("tools/call", { name: name, arguments: arguments }, token: token)
    assert_nil body["error"], "JSON-RPC error: #{body['error']}"
    body["result"]
  end

  # Calls a tool that should succeed; returns its structured content.
  def tool_ok(name, arguments = {}, **opts)
    result = call_tool(name, arguments, **opts)
    refute result["isError"], "#{name} failed: #{result.dig('content', 0, 'text')}"
    result["structuredContent"]
  end

  # Calls a tool that should fail; returns the error text.
  def tool_error(name, arguments = {}, **opts)
    result = call_tool(name, arguments, **opts)
    assert result["isError"], "#{name} should have failed, got: #{result['structuredContent'].inspect}"
    result.dig("content", 0, "text")
  end
end
