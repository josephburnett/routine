require "test_helper"

class RememberTest < ActiveSupport::TestCase
  test "validates presence of description" do
    remember = Remember.new(user: users(:one), state: "floating", decay: 1.0)
    assert_not remember.valid?
    assert_includes remember.errors[:description], "can't be blank"
  end

  test "validates state inclusion" do
    remember = Remember.new(user: users(:one), description: "Test", state: "invalid", decay: 1.0)
    assert_not remember.valid?
    assert_includes remember.errors[:state], "is not included in the list"
  end

  test "validates decay range" do
    remember = remembers(:floating_high)

    remember.decay = -0.1
    assert_not remember.valid?

    remember.decay = 1.1
    assert_not remember.valid?

    remember.decay = 0.5
    assert remember.valid?
  end

  test "soft_delete sets deleted to true" do
    remember = remembers(:floating_high)
    remember.soft_delete!
    assert remember.deleted
  end

  test "not_deleted scope excludes deleted records" do
    assert_not_includes Remember.not_deleted, remembers(:deleted_remember)
    assert_includes Remember.not_deleted, remembers(:floating_high)
  end

  test "pinned scope returns only pinned remembers" do
    pinned = Remember.pinned
    assert_includes pinned, remembers(:pinned_remember)
    assert_not_includes pinned, remembers(:floating_high)
  end

  test "retired scope returns only retired remembers" do
    retired = Remember.retired
    assert_includes retired, remembers(:retired_remember)
    assert_not_includes retired, remembers(:floating_high)
  end

  test "active scope returns pinned and floating" do
    active = Remember.active
    assert_includes active, remembers(:pinned_remember)
    assert_includes active, remembers(:floating_high)
    assert_not_includes active, remembers(:retired_remember)
  end

  test "visible_today? always returns true for pinned" do
    remember = remembers(:pinned_remember)
    assert remember.visible_today?
  end

  test "visible_today? always returns false for retired" do
    remember = remembers(:retired_remember)
    assert_not remember.visible_today?
  end

  test "visible_today? returns false when decay is 0" do
    remember = remembers(:floating_high)
    remember.decay = 0.0
    assert_not remember.visible_today?
  end

  test "visible_today? is stable for same day" do
    remember = remembers(:floating_high)
    remember.decay = 0.5

    # Call multiple times - should be consistent
    results = 10.times.map { remember.visible_today? }
    assert results.all? { |r| r == results.first }, "visible_today? should be stable within same day"
  end

  test "apply_decay! reduces decay by 20%" do
    remember = remembers(:floating_high)
    original_decay = remember.decay

    remember.apply_decay!
    assert_in_delta original_decay * 0.8, remember.decay, 0.001
  end

  test "apply_decay! does not go below 0.01" do
    remember = remembers(:floating_low)
    remember.update!(decay: 0.011)  # 0.011 * 0.8 = 0.0088, should clamp to 0.01

    remember.apply_decay!
    assert_equal 0.01, remember.decay
  end

  test "apply_decay! does nothing for pinned remembers" do
    remember = remembers(:pinned_remember)
    original_decay = remember.decay

    remember.apply_decay!
    assert_equal original_decay, remember.decay
  end

  test "apply_decay! does nothing for retired remembers" do
    remember = remembers(:retired_remember)
    original_decay = remember.decay

    remember.apply_decay!
    assert_equal original_decay, remember.decay
  end

  test "pin! sets state to pinned and decay to 1.0" do
    remember = remembers(:floating_low)

    remember.pin!
    assert_equal "pinned", remember.state
    assert_equal 1.0, remember.decay
  end

  test "bump_up! doubles decay up to 1.0" do
    remember = remembers(:floating_low)
    remember.update!(decay: 0.3)

    remember.bump_up!
    assert_equal 0.6, remember.decay
    assert_equal "floating", remember.state
  end

  test "bump_up! caps at 1.0" do
    remember = remembers(:floating_high)
    remember.update!(decay: 0.8)

    remember.bump_up!
    assert_equal 1.0, remember.decay
  end

  test "bump_down! halves decay to minimum 0.01" do
    remember = remembers(:floating_high)
    remember.update!(decay: 0.4)

    remember.bump_down!
    assert_equal 0.2, remember.decay
  end

  test "bump_down! does not go below 0.01" do
    remember = remembers(:floating_low)
    remember.update!(decay: 0.01)

    remember.bump_down!
    assert_equal 0.01, remember.decay
  end

  test "retire! sets state to retired and decay to 0" do
    remember = remembers(:floating_high)

    remember.retire!
    assert_equal "retired", remember.state
    assert_equal 0.0, remember.decay
  end

  test "sorted_by_visibility puts pinned first" do
    sorted = users(:one).remembers.not_deleted.sorted_by_visibility
    first_remember = sorted.first

    assert_equal "pinned", first_remember.state
  end

  test "items_in_namespace filters by namespace" do
    root_items = Remember.items_in_namespace(users(:one), "")
    namespaced_items = Remember.items_in_namespace(users(:one), "work.projects")

    assert_not_includes root_items, remembers(:namespaced_remember)
    assert_includes namespaced_items, remembers(:namespaced_remember)
  end
end
