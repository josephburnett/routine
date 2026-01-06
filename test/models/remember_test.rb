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

  test "visible_today? uses decay value for pinned items" do
    remember = remembers(:pinned_remember)
    # With decay 1.0, should always be visible
    assert remember.visible_today?

    # With decay 0.0, should not be visible (pinned doesn't bypass decay check)
    remember.decay = 0.0
    assert_not remember.visible_today?
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

  test "apply_decay! subtracts daily decay with jitter (default 0.05 ± 20%)" do
    remember = remembers(:floating_high)
    remember.update!(decay: 0.9)  # High enough to not hit floor
    original_decay = remember.decay

    remember.apply_decay!
    # With 20% jitter, decay should be between 0.04 and 0.06
    decay_amount = original_decay - remember.decay
    assert_in_delta 0.05, decay_amount, 0.015  # 0.05 ± 0.01 (allowing for 20% jitter)
  end

  test "apply_decay! does not go below hard min decay (default 0.01)" do
    remember = remembers(:floating_low)
    remember.update!(decay: 0.02)  # Below soft min, but should still clamp to hard min

    # Force decay by setting a very low personal floor
    user = remember.user
    user.create_user_setting!(
      remember_daily_decay: 0.05,
      remember_min_decay: 0.01,
      remember_soft_min_decay: 0.01,  # Same as hard min, so floor is always 0.01
      remember_decay_jitter: 0.0,
      backup_frequency: "daily"
    )

    remember.apply_decay!
    assert_equal 0.01, remember.decay

    user.user_setting.destroy
  end

  test "apply_decay! stops at personal_decay_floor" do
    user = users(:one)
    user.create_user_setting!(
      remember_daily_decay: 0.05,
      remember_min_decay: 0.01,
      remember_soft_min_decay: 0.10,
      remember_decay_jitter: 0.0,
      backup_frequency: "daily"
    )

    remember = remembers(:floating_high)
    floor = remember.personal_decay_floor

    # Set decay just above floor
    remember.update!(decay: floor + 0.01)
    remember.apply_decay!
    # Should have decayed
    assert remember.decay < floor + 0.01

    # Now set decay at floor - should not decay further
    remember.update!(decay: floor)
    original = remember.decay
    remember.apply_decay!
    assert_equal original, remember.decay

    user.user_setting.destroy
  end

  test "personal_decay_floor is between hard and soft min" do
    user = users(:one)
    user.create_user_setting!(
      remember_daily_decay: 0.05,
      remember_min_decay: 0.01,
      remember_soft_min_decay: 0.10,
      remember_decay_jitter: 0.0,
      backup_frequency: "daily"
    )

    remember = remembers(:floating_high)
    floor = remember.personal_decay_floor

    assert floor >= 0.01, "Floor should be >= hard min"
    assert floor <= 0.10, "Floor should be <= soft min"

    user.user_setting.destroy
  end

  test "personal_decay_floor is stable for same remember" do
    remember = remembers(:floating_high)

    floors = 10.times.map { remember.personal_decay_floor }
    assert floors.all? { |f| f == floors.first }, "personal_decay_floor should be stable"
  end

  test "apply_decay! uses user settings when available" do
    user = users(:one)
    user.create_user_setting!(
      remember_daily_decay: 0.1,
      remember_min_decay: 0.02,
      remember_soft_min_decay: 0.02,  # Same as hard to simplify test
      remember_decay_jitter: 0.0,     # No jitter for predictable test
      backup_frequency: "daily"
    )

    remember = remembers(:floating_high)
    remember.update!(decay: 0.5)

    remember.apply_decay!
    assert_in_delta 0.4, remember.decay, 0.001  # 0.5 - 0.1 = 0.4

    # Test hard min decay from settings
    remember.update!(decay: 0.05)
    remember.apply_decay!
    assert_equal 0.02, remember.decay  # 0.05 - 0.1 = -0.05, clamped to 0.02 (user's hard min)

    user.user_setting.destroy
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

  test "pin! sets state to pinned and preserves current decay" do
    remember = remembers(:floating_low)
    remember.update!(decay: 0.5)
    original_decay = remember.decay

    remember.pin!
    assert_equal "pinned", remember.state
    assert_equal original_decay, remember.decay
  end

  test "float! sets state to floating and preserves decay" do
    remember = remembers(:pinned_remember)
    remember.update!(decay: 0.7)
    original_decay = remember.decay

    remember.float!
    assert_equal "floating", remember.state
    assert_equal original_decay, remember.decay
  end

  test "float! sets decay to min_decay if below minimum" do
    user = users(:one)
    user.create_user_setting!(
      remember_daily_decay: 0.05,
      remember_min_decay: 0.1,
      remember_soft_min_decay: 0.1,
      backup_frequency: "daily"
    )

    remember = remembers(:retired_remember)
    # Retired has decay 0.0, which is below min

    remember.float!
    assert_equal "floating", remember.state
    assert_equal 0.1, remember.decay  # Should be set to min_decay

    user.user_setting.destroy
  end

  test "set_decay! sets decay value without changing state" do
    remember = remembers(:floating_high)
    original_state = remember.state

    remember.set_decay!(0.42)
    assert_equal original_state, remember.state
    assert_equal 0.42, remember.decay
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

  test "bump_down! does not go below min decay (default 0.01)" do
    remember = remembers(:floating_low)
    remember.update!(decay: 0.01)

    remember.bump_down!
    assert_equal 0.01, remember.decay
  end

  test "bump_down! uses user min_decay setting" do
    user = users(:one)
    user.create_user_setting!(
      remember_daily_decay: 0.05,
      remember_min_decay: 0.1,
      remember_soft_min_decay: 0.1,
      backup_frequency: "daily"
    )

    remember = remembers(:floating_high)
    remember.update!(decay: 0.15)

    remember.bump_down!
    assert_equal 0.1, remember.decay  # 0.15 / 2 = 0.075, clamped to 0.1 (user's min)

    user.user_setting.destroy
  end

  test "retire! sets state to retired and decay to 0" do
    remember = remembers(:floating_high)

    remember.retire!
    assert_equal "retired", remember.state
    assert_equal 0.0, remember.decay
  end

  test "sorted_by_decay orders by decay descending" do
    sorted = users(:one).remembers.not_deleted.sorted_by_decay
    decays = sorted.map(&:decay)

    assert_equal decays, decays.sort.reverse, "Should be sorted by decay descending"
  end

  test "items_in_namespace filters by namespace" do
    root_items = Remember.items_in_namespace(users(:one), "")
    namespaced_items = Remember.items_in_namespace(users(:one), "work.projects")

    assert_not_includes root_items, remembers(:namespaced_remember)
    assert_includes namespaced_items, remembers(:namespaced_remember)
  end

  # Recursive namespace tests
  test "in_namespace_recursive with blank namespace returns all user remembers" do
    all_remembers = Remember.in_namespace_recursive(users(:one), "")

    assert_includes all_remembers, remembers(:pinned_remember)
    assert_includes all_remembers, remembers(:floating_high)
    assert_includes all_remembers, remembers(:namespaced_remember)
    assert_includes all_remembers, remembers(:work_remember)
    assert_includes all_remembers, remembers(:nested_deep_remember)
    assert_not_includes all_remembers, remembers(:user_two_remember)
  end

  test "in_namespace_recursive with namespace returns exact and child namespaces" do
    work_remembers = Remember.in_namespace_recursive(users(:one), "work")

    # Should include "work" namespace
    assert_includes work_remembers, remembers(:work_remember)
    # Should include "work.projects" namespace
    assert_includes work_remembers, remembers(:namespaced_remember)
    # Should include "work.projects.urgent" namespace
    assert_includes work_remembers, remembers(:nested_deep_remember)
    # Should NOT include root namespace
    assert_not_includes work_remembers, remembers(:pinned_remember)
    assert_not_includes work_remembers, remembers(:floating_high)
  end

  test "in_namespace_recursive with deep namespace returns only that and children" do
    project_remembers = Remember.in_namespace_recursive(users(:one), "work.projects")

    # Should include "work.projects" namespace
    assert_includes project_remembers, remembers(:namespaced_remember)
    # Should include "work.projects.urgent" namespace
    assert_includes project_remembers, remembers(:nested_deep_remember)
    # Should NOT include "work" namespace (parent)
    assert_not_includes project_remembers, remembers(:work_remember)
    # Should NOT include root namespace
    assert_not_includes project_remembers, remembers(:pinned_remember)
  end

  test "in_namespace_recursive does not match partial namespace names" do
    # Create a remember in "eworker" namespace - should NOT match "work"
    worker_remember = Remember.create!(
      user: users(:one),
      description: "Worker remember",
      state: "floating",
      decay: 0.5,
      namespace: "worker"
    )

    work_remembers = Remember.in_namespace_recursive(users(:one), "work")

    assert_not_includes work_remembers, worker_remember

    worker_remember.destroy
  end

  test "visible_today_recursive includes child namespaces" do
    # The nested_deep_remember is pinned so it should always be visible
    visible = Remember.visible_today_recursive(users(:one), "work")

    # Pinned remember in work.projects.urgent should be included
    assert_includes visible, remembers(:nested_deep_remember)
  end

  test "visible_today_recursive excludes retired and deleted" do
    visible = Remember.visible_today_recursive(users(:one), "")

    assert_not_includes visible, remembers(:retired_remember)
    assert_not_includes visible, remembers(:deleted_remember)
  end

  test "visible_today_recursive respects user isolation" do
    visible = Remember.visible_today_recursive(users(:one), "")

    assert_not_includes visible, remembers(:user_two_remember)
  end
end
