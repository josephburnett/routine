require "test_helper"
require_relative "mcp_test_helper"

class McpRememberToolsTest < ActionDispatch::IntegrationTest
  include McpTestHelper

  setup do
    @user = users(:one)
  end

  test "save_remember creates a floating remember like the new page" do
    result = tool_ok("save_remember", { description: "Call mom", background: "Sundays", namespace: "family" })
    remember = Remember.find(result["id"])

    assert_equal [ "Call mom", "Sundays", "family", "floating", 1.0 ],
                 [ remember.description, remember.background, remember.namespace, remember.state, remember.decay ]
    assert_equal @user, remember.user
  end

  test "save_remember needs a description to create" do
    assert_match "description is required", tool_error("save_remember", { background: "no title" })
  end

  test "save_remember updates only the given fields" do
    remember = remembers(:floating_high)
    tool_ok("save_remember", { id: remember.id, background: "New notes" })

    remember.reload
    assert_equal "New notes", remember.background
    assert_equal "High priority floating remember", remember.description
  end

  test "remember_action applies each button's model method" do
    remember = remembers(:floating_low)

    assert_equal "pinned", tool_ok("remember_action", { remember_id: remember.id, action: "pin" })["state"]
    assert_equal "floating", tool_ok("remember_action", { remember_id: remember.id, action: "float" })["state"]

    before = remember.reload.decay
    up = tool_ok("remember_action", { remember_id: remember.id, action: "bump_up" })
    assert up["decay"] > before

    down = tool_ok("remember_action", { remember_id: remember.id, action: "bump_down" })
    assert down["decay"] < up["decay"]

    retired = tool_ok("remember_action", { remember_id: remember.id, action: "retire" })
    assert_equal [ "retired", 0 ], [ retired["state"], retired["decay"] ]
  end

  test "set_decay is kept within the user's limits, like the decay slider" do
    remember = remembers(:floating_high)
    assert_equal 0.5, tool_ok("remember_action", { remember_id: remember.id, action: "set_decay", decay: 0.5 })["decay"]
    assert_equal 1, tool_ok("remember_action", { remember_id: remember.id, action: "set_decay", decay: 7 })["decay"]
    assert_equal 0.01, tool_ok("remember_action", { remember_id: remember.id, action: "set_decay", decay: 0 })["decay"]
    assert_match "needs decay", tool_error("remember_action", { remember_id: remember.id, action: "set_decay" })
  end

  test "remember tools can't touch other users' remembers" do
    theirs = Remember.create!(user: users(:two), description: "Not yours")
    assert_match "Not found", tool_error("remember_action", { remember_id: theirs.id, action: "retire" })
    assert_match "Not found", tool_error("save_remember", { id: theirs.id, description: "Mine now" })
    assert_equal "floating", theirs.reload.state
  end
end
