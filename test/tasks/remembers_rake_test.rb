require "test_helper"
require "rake"

class RemembersRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("remembers:lift_to_minimum")
    Rake::Task["remembers:lift_to_minimum"].reenable
  end

  test "lift_to_minimum lifts low floating remembers and leaves the rest" do
    users(:one).create_user_setting!(remember_min_decay: 0.10, backup_frequency: "daily")
    low = Remember.create!(user: users(:one), description: "Low", decay: 0.01)
    pinned = Remember.create!(user: users(:one), description: "Pinned low", decay: 0.02, state: "pinned")
    other = Remember.create!(user: users(:two), description: "Default minimum", decay: 0.01)

    assert_output(/Lifted 1 remember/) { Rake::Task["remembers:lift_to_minimum"].invoke }

    assert_includes 0.10..0.15, low.reload.decay
    assert_equal 0.02, pinned.reload.decay
    assert_equal 0.01, other.reload.decay
  end
end
