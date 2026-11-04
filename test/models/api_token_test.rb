require "test_helper"

class ApiTokenTest < ActiveSupport::TestCase
  test "issue! stores only a digest and returns the plain token once" do
    token, plain = ApiToken.issue!(user: users(:one), name: "cli")

    assert plain.start_with?("rt_")
    assert plain.length > 30
    assert_equal ApiToken.digest(plain), token.token_digest
    refute_includes token.attributes.values.map(&:to_s), plain
  end

  test "authenticate finds active tokens only" do
    token, plain = ApiToken.issue!(user: users(:one), name: "cli")
    assert_equal token, ApiToken.authenticate(plain)
    assert_nil ApiToken.authenticate("rt_wrong")
    assert_nil ApiToken.authenticate(nil)

    token.revoke!
    assert_nil ApiToken.authenticate(plain)
  end

  test "tokens are unique per issue" do
    _, a = ApiToken.issue!(user: users(:one), name: "a")
    _, b = ApiToken.issue!(user: users(:one), name: "b")
    refute_equal a, b
  end
end
