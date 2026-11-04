# The MCP endpoint (Streamable HTTP, stateless, JSON responses). Each POST is a
# JSON-RPC message, authenticated with an API token:
#   Authorization: Bearer rt_...
class McpController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods

  before_action :authenticate

  def handle
    result = RoutineMcp.server(@api_token.user).handle_json(request.raw_post)

    if result.nil?
      # Notifications and responses get no reply
      head :accepted
    else
      render json: result
    end
  end

  # No server-to-client stream and no sessions in stateless mode
  def not_allowed
    response.set_header("Allow", "POST")
    head :method_not_allowed
  end

  private

  def authenticate
    @api_token = authenticate_with_http_token { |token, _options| ApiToken.authenticate(token) }
    return if @api_token

    response.set_header("WWW-Authenticate", 'Bearer realm="routine"')
    render json: { error: "Invalid or missing API token" }, status: :unauthorized
  end
end
