require "test_helper"

class RemembersControllerTest < ActionDispatch::IntegrationTest
  setup do
    login_as_user_one
  end

  test "should get index" do
    get remembers_path
    assert_response :success
  end

  test "should get index with namespace" do
    get remembers_path(namespace: "work.projects")
    assert_response :success
  end

  test "should get new" do
    get new_remember_path
    assert_response :success
  end

  test "should create remember" do
    assert_difference("Remember.count") do
      post remembers_path, params: {
        remember: {
          description: "New test remember",
          background: "Some background info",
          namespace: ""
        }
      }
    end

    remember = Remember.last
    assert_equal "New test remember", remember.description
    assert_equal "floating", remember.state
    assert_equal 1.0, remember.decay
    assert_redirected_to remembers_path(namespace: "")
  end

  test "should show remember" do
    get remember_path(remembers(:floating_high))
    assert_response :success
  end

  test "should get edit" do
    get edit_remember_path(remembers(:floating_high))
    assert_response :success
  end

  test "should update remember" do
    remember = remembers(:floating_high)
    patch remember_path(remember), params: {
      remember: { description: "Updated description" }
    }
    assert_redirected_to remember_path(remember)
    remember.reload
    assert_equal "Updated description", remember.description
  end

  test "should soft delete remember" do
    remember = remembers(:floating_high)
    patch soft_delete_remember_path(remember)
    assert_redirected_to remembers_path(namespace: remember.namespace)
    remember.reload
    assert remember.deleted
  end

  test "should pin remember and preserve decay" do
    remember = remembers(:floating_high)
    remember.update!(decay: 0.7)
    original_decay = remember.decay

    patch pin_remember_path(remember)
    assert_redirected_to remembers_path(namespace: remember.namespace)
    remember.reload
    assert_equal "pinned", remember.state
    assert_equal original_decay, remember.decay
  end

  test "should float remember" do
    remember = remembers(:pinned_remember)
    remember.update!(decay: 0.6)
    original_decay = remember.decay

    patch float_remember_path(remember)
    assert_redirected_to remembers_path(namespace: remember.namespace)
    remember.reload
    assert_equal "floating", remember.state
    assert_equal original_decay, remember.decay
  end

  test "should set decay without changing state" do
    remember = remembers(:floating_high)
    original_state = remember.state

    patch set_decay_remember_path(remember), params: { decay: 0.42 }
    assert_redirected_to remember_path(remember)
    remember.reload
    assert_equal original_state, remember.state
    assert_in_delta 0.42, remember.decay, 0.001
  end

  test "set_decay clamps to min/max" do
    user = users(:one)
    user.create_user_setting!(
      remember_daily_decay: 0.05,
      remember_min_decay: 0.1,
      remember_soft_min_decay: 0.1,
      backup_frequency: "daily"
    )

    remember = remembers(:floating_high)

    # Test clamping below min
    patch set_decay_remember_path(remember), params: { decay: 0.01 }
    remember.reload
    assert_equal 0.1, remember.decay  # Clamped to min

    # Test clamping above max
    patch set_decay_remember_path(remember), params: { decay: 1.5 }
    remember.reload
    assert_equal 1.0, remember.decay  # Clamped to max

    user.user_setting.destroy
  end

  test "should bump up remember" do
    remember = remembers(:floating_low)
    remember.update!(decay: 0.3)
    patch bump_up_remember_path(remember)
    assert_redirected_to remembers_path(namespace: remember.namespace)
    remember.reload
    assert_equal 0.6, remember.decay
  end

  test "should bump down remember" do
    remember = remembers(:floating_high)
    remember.update!(decay: 0.4)
    patch bump_down_remember_path(remember)
    assert_redirected_to remembers_path(namespace: remember.namespace)
    remember.reload
    assert_equal 0.2, remember.decay
  end

  test "should retire remember" do
    remember = remembers(:floating_high)
    patch retire_remember_path(remember)
    assert_redirected_to remembers_path(namespace: remember.namespace)
    remember.reload
    assert_equal "retired", remember.state
    assert_equal 0.0, remember.decay
  end

  # Display action tests
  test "should get display" do
    get display_remembers_path
    assert_response :success
  end

  test "should get display with namespace" do
    get display_remembers_path(namespace: "work")
    assert_response :success
  end

  test "display action returns to display view after pin" do
    remember = remembers(:floating_high)
    patch pin_remember_path(remember, return_to: "display", display_namespace: "")
    assert_redirected_to display_remembers_path(namespace: "")
  end

  test "display action returns to display view after bump_up" do
    remember = remembers(:floating_low)
    patch bump_up_remember_path(remember, return_to: "display", display_namespace: "work")
    assert_redirected_to display_remembers_path(namespace: "work")
  end

  test "should not access another user's remember" do
    get remember_path(remembers(:user_two_remember))
    assert_response :not_found
  end

  test "should not access deleted remember" do
    get remember_path(remembers(:deleted_remember))
    assert_response :not_found
  end

  test "requires login" do
    delete logout_path
    get remembers_path
    assert_redirected_to login_path
  end
end
