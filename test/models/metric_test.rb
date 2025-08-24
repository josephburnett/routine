require "test_helper"

class MetricTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)

    # Create a unique question for this test to avoid interference
    @question = Question.create!(
      name: "Test Question #{SecureRandom.hex(4)}",
      question_type: "number",
      user: @user
    )

    # Create a form and response to associate answers with
    @form = Form.create!(
      user: @user,
      name: "Test Form #{SecureRandom.hex(4)}"
    )

    @response = Response.create!(
      user: @user,
      form: @form
    )

    # Freeze time to a known point for predictable tests
    # Tuesday, June 27, 2025, 2:30 PM
    @fixed_time = Time.zone.parse("2025-06-27 14:30:00")
    travel_to @fixed_time
  end

  def teardown
    travel_back
  end

  # =============================================================================
  # WIDTH BEHAVIOR TESTS
  # =============================================================================

  test "daily width should return data since midnight today" do
    metric = create_metric(width: "daily", resolution: "hour", function: "average")

    # Create answers at different times
    create_answer(value: 10, time: @fixed_time - 2.days)        # Should be excluded (before today)
    create_answer(value: 20, time: @fixed_time.beginning_of_day) # Should be included (start of today)
    create_answer(value: 30, time: @fixed_time - 1.hour)        # Should be included (today)
    create_answer(value: 40, time: @fixed_time)                 # Should be included (now)

    series = metric.series

    # Should only include data from midnight today onwards
    expected_start_time = @fixed_time.beginning_of_day
    expected_end_time = @fixed_time

    assert series.all? { |time, value| time >= expected_start_time && time <= expected_end_time },
           "Daily width should only include data from midnight today onwards"

    # Should include the 20, 30, and 40 values but not the 10
    values = series.map(&:last)
    assert_not_includes values, 10, "Should not include data from before today"
    assert_includes values, 20, "Should include data from start of today"
  end

  test "weekly width should return data since midnight on Saturday this week" do
    metric = create_metric(width: "weekly", resolution: "day")

    # Current time is Tuesday June 27, 2025
    # This week's Saturday would be June 21, 2025
    week_start = @fixed_time.beginning_of_week(:saturday)

    create_answer(value: 10, time: week_start - 1.day)  # Should be excluded (before this week)
    create_answer(value: 20, time: week_start)          # Should be included (start of week)
    create_answer(value: 30, time: @fixed_time)         # Should be included (now)

    series = metric.series

    assert series.all? { |time, value| time >= week_start },
           "Weekly width should only include data from midnight Saturday this week onwards"
  end

  test "monthly width should return data since midnight on 1st of month" do
    metric = create_metric(width: "monthly", resolution: "day")

    # June 1, 2025
    month_start = @fixed_time.beginning_of_month

    create_answer(value: 10, time: month_start - 1.day)  # Should be excluded (before this month)
    create_answer(value: 20, time: month_start)          # Should be included (start of month)
    create_answer(value: 30, time: @fixed_time)          # Should be included (now)

    series = metric.series

    assert series.all? { |time, value| time >= month_start },
           "Monthly width should only include data from midnight 1st of month onwards"
  end

  test "90_days width should return sliding window of exactly 90 days back" do
    metric = create_metric(width: "90_days", resolution: "day")

    # 90 days ago from now, to midnight on the first day
    days_90_start = (@fixed_time - 90.days).beginning_of_day

    create_answer(value: 10, time: days_90_start - 1.day)  # Should be excluded (before 90 days)
    create_answer(value: 20, time: days_90_start)          # Should be included (exactly 90 days ago)
    create_answer(value: 30, time: @fixed_time)            # Should be included (now)

    series = metric.series

    assert series.all? { |time, value| time >= days_90_start },
           "90_days width should include data from exactly 90 days ago to now"
  end

  test "yearly width should return data since midnight on January 1st" do
    metric = create_metric(width: "yearly", resolution: "day")

    # January 1, 2025
    year_start = @fixed_time.beginning_of_year

    create_answer(value: 10, time: year_start - 1.day)  # Should be excluded (before this year)
    create_answer(value: 20, time: year_start)          # Should be included (start of year)
    create_answer(value: 30, time: @fixed_time)         # Should be included (now)

    series = metric.series

    assert series.all? { |time, value| time >= year_start },
           "Yearly width should only include data from midnight January 1st onwards"
  end

  test "all_time width should return all available data" do
    metric = create_metric(width: "all_time", resolution: "day")

    # Create answers across a wide time range
    create_answer(value: 10, time: @fixed_time - 5.years)
    create_answer(value: 20, time: @fixed_time - 1.year)
    create_answer(value: 30, time: @fixed_time)

    series = metric.series
    values = series.map(&:last)

    # Should include all values
    assert_includes values, 10, "All_time should include very old data"
    assert_includes values, 20, "All_time should include old data"
    assert_includes values, 30, "All_time should include current data"
  end

  # =============================================================================
  # NEW SLIDING WINDOW WIDTH TESTS
  # =============================================================================

  test "7_days width should return sliding window of exactly 7 days back" do
    metric = create_metric(width: "7_days", resolution: "day")

    # 7 days ago from now, to midnight on the first day
    days_7_start = (@fixed_time - 7.days).beginning_of_day

    create_answer(value: 10, time: days_7_start - 1.day)  # Should be excluded
    create_answer(value: 20, time: days_7_start)          # Should be included
    create_answer(value: 30, time: @fixed_time)           # Should be included

    series = metric.series

    assert series.all? { |time, value| time >= days_7_start },
           "7_days width should include data from exactly 7 days ago to now"
  end

  test "30_days width should return sliding window of exactly 30 days back" do
    metric = create_metric(width: "30_days", resolution: "day")

    # 30 days ago from now, to midnight on the first day
    days_30_start = (@fixed_time - 30.days).beginning_of_day

    create_answer(value: 10, time: days_30_start - 1.day)  # Should be excluded
    create_answer(value: 20, time: days_30_start)          # Should be included
    create_answer(value: 30, time: @fixed_time)            # Should be included

    series = metric.series

    assert series.all? { |time, value| time >= days_30_start },
           "30_days width should include data from exactly 30 days ago to now"
  end

  # =============================================================================
  # RESOLUTION/BUCKET BEHAVIOR TESTS
  # =============================================================================

  test "five_minute resolution buckets data into 5-minute intervals" do
    metric = create_metric(width: "daily", resolution: "five_minute", function: "average")

    # Create answers within the same 5-minute bucket (14:25 - 14:29:59)
    base_time = @fixed_time.beginning_of_hour + 25.minutes  # 14:25:00
    create_answer(value: 10, time: base_time)               # 14:25:00
    create_answer(value: 20, time: base_time + 2.minutes)   # 14:27:00
    create_answer(value: 30, time: base_time + 4.minutes)   # 14:29:00

    # Create answer in current 5-minute bucket (14:30 - 14:34:59)
    create_answer(value: 40, time: @fixed_time)             # 14:30:00

    series = metric.series

    # Should have 2 buckets
    assert_equal 2, series.length, "Should have 2 five-minute buckets"

    # First bucket should contain average of 10+20+30=20
    first_bucket = series.find { |time, value| time == base_time }
    assert_not_nil first_bucket, "Should have bucket at 14:25:00"
    assert_equal 20.0, first_bucket.last, "First bucket should average to 20"

    # Second bucket should contain 40
    second_bucket_time = @fixed_time.beginning_of_hour + 30.minutes  # 14:30:00
    second_bucket = series.find { |time, value| time == second_bucket_time }
    assert_not_nil second_bucket, "Should have bucket at 14:30:00"
    assert_equal 40.0, second_bucket.last, "Second bucket should contain 40"
  end

  test "hour resolution buckets data into hourly intervals" do
    metric = create_metric(width: "daily", resolution: "hour", function: "average")

    # Create answers within the same hour (14:00 - 14:59:59)
    hour_start = @fixed_time.beginning_of_hour  # 14:00:00
    create_answer(value: 10, time: hour_start)
    create_answer(value: 20, time: hour_start + 15.minutes)
    create_answer(value: 30, time: hour_start + 25.minutes)

    # Create answer in previous hour (within daily range)
    prev_hour = hour_start - 1.hour  # 13:00:00
    create_answer(value: 40, time: prev_hour)

    series = metric.series

    # Should have 2 buckets (13:00 and 14:00)
    assert_equal 2, series.length, "Should have 2 hourly buckets"

    # 14:00 bucket should contain average of 10+20+30=20
    current_bucket = series.find { |time, value| time == hour_start }
    assert_equal 20.0, current_bucket.last, "Current hour bucket should average to 20"

    # 13:00 bucket should contain 40
    prev_bucket = series.find { |time, value| time == prev_hour }
    assert_equal 40.0, prev_bucket.last, "Previous hour bucket should contain 40"
  end

  test "day resolution buckets data into daily intervals" do
    metric = create_metric(width: "weekly", resolution: "day", function: "average")

    # Create answers within the same day
    day_start = @fixed_time.beginning_of_day
    create_answer(value: 10, time: day_start)
    create_answer(value: 20, time: day_start + 12.hours)
    create_answer(value: 30, time: @fixed_time)  # 14:30 same day

    # Create answer in previous day (within weekly range)
    prev_day = day_start - 1.day
    create_answer(value: 40, time: prev_day)

    series = metric.series

    # Current day bucket should contain average of 10+20+30=20
    current_day_bucket = series.find { |time, value| time == day_start }
    assert_equal 20.0, current_day_bucket.last, "Current day bucket should average to 20"

    # Previous day bucket should contain 40
    prev_day_bucket = series.find { |time, value| time == prev_day }
    assert_equal 40.0, prev_day_bucket.last, "Previous day bucket should contain 40"
  end

  test "week resolution buckets data into weekly intervals" do
    metric = create_metric(width: "monthly", resolution: "week", function: "average")

    # Create answers within the same week (using default Monday start)
    week_start = @fixed_time.beginning_of_week
    create_answer(value: 10, time: week_start)
    create_answer(value: 20, time: week_start + 3.days)
    create_answer(value: 30, time: @fixed_time)  # Current time

    # Create answer in previous week (within monthly range)
    prev_week = week_start - 1.week
    create_answer(value: 40, time: prev_week)

    series = metric.series

    # Current week bucket should contain average of 10+20+30=20
    current_week_bucket = series.find { |time, value| time == week_start }
    assert_equal 20.0, current_week_bucket.last, "Current week bucket should average to 20"

    # Previous week bucket should contain 40
    prev_week_bucket = series.find { |time, value| time == prev_week }
    assert_equal 40.0, prev_week_bucket.last, "Previous week bucket should contain 40"
  end

  test "month resolution buckets data into monthly intervals" do
    metric = create_metric(width: "yearly", resolution: "month", function: "average")

    # Create answers within the same month
    month_start = @fixed_time.beginning_of_month
    create_answer(value: 10, time: month_start)
    create_answer(value: 20, time: month_start + 15.days)
    create_answer(value: 30, time: @fixed_time)  # Current time

    # Create answer in previous month (within yearly range)
    prev_month = month_start - 1.month
    create_answer(value: 40, time: prev_month)

    series = metric.series

    # Current month bucket should contain average of 10+20+30=20
    current_month_bucket = series.find { |time, value| time == month_start }
    assert_equal 20.0, current_month_bucket.last, "Current month bucket should average to 20"

    # Previous month bucket should contain 40
    prev_month_bucket = series.find { |time, value| time == prev_month }
    assert_equal 40.0, prev_month_bucket.last, "Previous month bucket should contain 40"
  end

  # =============================================================================
  # ANSWER AGGREGATION BEHAVIOR TESTS
  # =============================================================================

  test "no data maintains previous value - buckets with no answers preserve last known value" do
    metric = create_metric(width: "daily", resolution: "hour", function: "average")
    metric.update!(fill: "previous")

    # Create answers with gaps
    base_time = @fixed_time.beginning_of_day
    create_answer(value: 100, time: base_time)           # 00:00 - has data
    # Gap at 01:00 - no data, should maintain 100
    create_answer(value: 200, time: base_time + 2.hours) # 02:00 - has data
    # Gap at 03:00 - no data, should maintain 200
    # Gap at 04:00 - no data, should maintain 200

    series = metric.series

    # Should have entries for all hours from 00:00 to current time
    # Gaps should maintain the previous value
    hour_00 = series.find { |time, value| time == base_time }
    hour_01 = series.find { |time, value| time == base_time + 1.hour }
    hour_02 = series.find { |time, value| time == base_time + 2.hours }
    hour_03 = series.find { |time, value| time == base_time + 3.hours }

    assert_equal 100, hour_00.last, "Hour 00 should have actual value 100"
    assert_equal 100, hour_01.last, "Hour 01 should maintain previous value 100"
    assert_equal 200, hour_02.last, "Hour 02 should have actual value 200"
    assert_equal 200, hour_03.last, "Hour 03 should maintain previous value 200"
  end

  test "sum function sums multiple answers in same bucket" do
    metric = create_metric(width: "daily", resolution: "hour", function: "sum")

    # Create multiple answers in the same hour bucket
    hour_start = @fixed_time.beginning_of_hour
    create_answer(value: 10, time: hour_start)
    create_answer(value: 20, time: hour_start + 15.minutes)
    create_answer(value: 30, time: hour_start + 25.minutes)

    series = metric.series

    # Should have one bucket with summed value
    bucket = series.find { |time, value| time == hour_start }
    assert_not_nil bucket, "Should have bucket for the hour"

    # Test that multiple answers are summed
    expected_sum = 10.0 + 20.0 + 30.0
    actual_value = bucket.last

    assert_equal expected_sum, actual_value, "Multiple answers in same bucket should be summed for sum function"
  end

  test "average function averages multiple answers in same bucket" do
    metric = create_metric(width: "daily", resolution: "hour", function: "average")

    # Create multiple answers in the same hour bucket
    hour_start = @fixed_time.beginning_of_hour
    create_answer(value: 10, time: hour_start)
    create_answer(value: 20, time: hour_start + 15.minutes)
    create_answer(value: 30, time: hour_start + 25.minutes)

    series = metric.series

    # Should have one bucket with averaged value
    bucket = series.find { |time, value| time == hour_start }
    assert_not_nil bucket, "Should have bucket for the hour"

    # Test that multiple answers are averaged
    expected_average = (10.0 + 20.0 + 30.0) / 3.0
    actual_value = bucket.last

    assert_equal expected_average, actual_value, "Multiple answers in same bucket should be averaged for average function"
  end

  test "difference function subtracts later values from first in same bucket" do
    metric = create_metric(width: "daily", resolution: "hour", function: "difference")

    # Create multiple answers in the same hour bucket
    hour_start = @fixed_time.beginning_of_hour
    create_answer(value: 50, time: hour_start)
    create_answer(value: 10, time: hour_start + 15.minutes)
    create_answer(value: 5, time: hour_start + 25.minutes)

    series = metric.series

    # Should have one bucket with difference value
    bucket = series.find { |time, value| time == hour_start }
    assert_not_nil bucket, "Should have bucket for the hour"

    # Test that multiple answers are processed as: first - (sum of rest)
    expected_difference = 50.0 - (10.0 + 5.0)
    actual_value = bucket.last

    assert_equal expected_difference, actual_value, "Multiple answers in same bucket should follow difference logic for difference function"
  end

  test "weekly sum metric correctly sums daily exercise minutes" do
    # This tests the exact scenario from production: Exercise Minutes metric
    # with function: sum, resolution: week, width: 90_days
    weekly_metric = create_metric(width: "90_days", resolution: "week", function: "sum")

    # Create daily exercise data within the same week
    # Use times that are definitely all in the same week
    base_time = @fixed_time.beginning_of_week  # Monday 00:00

    # Create 4 exercise entries on different days within the same week
    create_answer(value: 30, time: base_time + 0.days)  # Monday
    create_answer(value: 20, time: base_time + 1.day)   # Tuesday
    create_answer(value: 15, time: base_time + 2.days)  # Wednesday
    create_answer(value: 45, time: base_time + 4.days)  # Friday

    series = weekly_metric.series

    # Should have one weekly bucket that sums all daily values
    week_bucket = series.find { |time, value| time == base_time }
    assert_not_nil week_bucket, "Should have bucket for the week"

    # Total should be sum of all daily values: 30+20+15+45 = 110
    expected_weekly_total = 30.0 + 20.0 + 15.0 + 45.0
    actual_value = week_bucket.last

    assert_equal expected_weekly_total, actual_value, "Weekly sum should add up all daily exercise minutes, not average them"

    # Also verify it's not accidentally averaging (which would be 110/4 = 27.5)
    incorrect_average = expected_weekly_total / 4.0
    assert_not_equal incorrect_average, actual_value, "Weekly sum should NOT be averaging the daily values"
  end

  # =============================================================================
  # WRAP FEATURE BEHAVIOR TESTS
  # =============================================================================

  test "wrap feature overlaps data within selected window and then averages" do
    metric = create_metric(width: "weekly", resolution: "hour", wrap: "day", function: "average")

    # Create answers across multiple days at the same hour
    day1 = @fixed_time.beginning_of_week(:saturday)
    day2 = day1 + 1.day
    day3 = day1 + 2.days

    # All at 10:00 AM on different days
    target_hour = 10
    create_answer(value: 100, time: day1 + target_hour.hours)
    create_answer(value: 200, time: day2 + target_hour.hours)
    create_answer(value: 300, time: day3 + target_hour.hours)

    # Different hour on same days
    create_answer(value: 50, time: day1 + 14.hours)  # 2:00 PM
    create_answer(value: 75, time: day2 + 14.hours)  # 2:00 PM

    series = metric.series

    # After wrapping by day, multiple 10:00 AM values should be in same bucket
    # and should be averaged: (100 + 200 + 300) / 3 = 200
    ten_am_bucket = series.find { |time, value| time.hour == target_hour }

    # Test the wrap feature behavior
    assert_not_nil ten_am_bucket, "Should have bucket for 10:00 AM"
    assert_equal 200, ten_am_bucket.last, "Wrapped 10 AM values should be averaged"

    # 2:00 PM values should be averaged: (50 + 75) / 2 = 62.5
    two_pm_bucket = series.find { |time, value| time.hour == 14 }
    assert_not_nil two_pm_bucket, "Should have bucket for 2:00 PM"
    assert_equal 62.5, two_pm_bucket.last, "Wrapped 2 PM values should be averaged"
  end

  test "wrap by hour maps data to positions within reference hour" do
    metric = create_metric(width: "daily", resolution: "five_minute", wrap: "hour", function: "average")

    # Create answers at same minute within different hours
    base_time = @fixed_time.beginning_of_day
    create_answer(value: 10, time: base_time + 1.hour + 15.minutes)  # 01:15
    create_answer(value: 20, time: base_time + 2.hours + 15.minutes) # 02:15
    create_answer(value: 30, time: base_time + 3.hours + 15.minutes) # 03:15

    series = metric.series

    # After wrapping by hour, all :15 minute values should overlap
    # Should be averaged: (10 + 20 + 30) / 3 = 20

    fifteen_minute_bucket = series.find { |time, value| time.min == 15 }
    assert_not_nil fifteen_minute_bucket, "Should have bucket for :15 minutes"
    assert_equal 20, fifteen_minute_bucket.last, "Wrapped :15 values should be averaged"
  end

  test "wrap by weekly maps data to positions within reference week" do
    metric = create_metric(width: "monthly", resolution: "day", wrap: "weekly", function: "average")

    # Create answers on the same day of week (Tuesday) across different weeks within the month
    # Current time is June 27, 2025 (Friday), so use recent Tuesdays
    current_tuesday = @fixed_time.beginning_of_week + 1.day  # Tuesday of current week
    prev_tuesday = current_tuesday - 1.week                  # Previous Tuesday
    prev2_tuesday = current_tuesday - 2.weeks                # Two weeks ago Tuesday

    create_answer(value: 100, time: prev2_tuesday)
    create_answer(value: 200, time: prev_tuesday)
    create_answer(value: 300, time: current_tuesday)

    # Different day of week (Wednesday)
    current_wednesday = current_tuesday + 1.day
    create_answer(value: 50, time: current_wednesday)

    series = metric.series

    # After wrapping by week, all Tuesday values should overlap and average

    # Should find bucket for Tuesday position with averaged value (100+200+300)/3 = 200
    tuesday_bucket = series.find { |time, value| time.wday == current_tuesday.wday }
    assert_not_nil tuesday_bucket, "Should have bucket for Tuesday"
    assert_equal 200.0, tuesday_bucket.last, "Wrapped Tuesday values should be averaged"
  end

  # =============================================================================
  # EDGE CASE TESTS
  # =============================================================================

  test "empty data returns empty series" do
    metric = create_metric(width: "daily", resolution: "hour", function: "average")
    # Don't create any answers

    series = metric.series
    assert_empty series, "Metric with no data should return empty series"
  end

  test "single data point returns single bucket" do
    metric = create_metric(width: "daily", resolution: "hour", function: "average")
    create_answer(value: 42, time: @fixed_time)

    series = metric.series
    assert_equal 1, series.length, "Single data point should create single bucket"
    assert_equal 42, series.first.last, "Single data point should preserve its value"
  end

  test "data exactly at boundary times is included correctly" do
    metric = create_metric(width: "daily", resolution: "hour", function: "average")

    # Create answer exactly at start of day
    day_start = @fixed_time.beginning_of_day
    create_answer(value: 100, time: day_start)

    series = metric.series
    boundary_bucket = series.find { |time, value| time == day_start }
    assert_not_nil boundary_bucket, "Data at exact boundary should be included"
    assert_equal 100, boundary_bucket.last, "Boundary data should preserve value"
  end

  test "scale factor is applied to answer values" do
    metric = create_metric(width: "daily", resolution: "hour", scale: 2.5)
    create_answer(value: 10, time: @fixed_time)

    series = metric.series
    assert_equal 25.0, series.first.last, "Scale factor should be applied (10 * 2.5 = 25)"
  end


  test "different answer types are converted to numeric correctly" do
    metric = create_metric(width: "daily", resolution: "hour", function: "average")

    # Create answers of different types (all within time range)
    create_answer(value: 42, time: @fixed_time, answer_type: "number")
    create_answer(value: true, time: @fixed_time - 1.minute, answer_type: "bool")
    create_answer(value: false, time: @fixed_time - 2.minutes, answer_type: "bool")

    series = metric.series

    # Should average: (42 + 1 + 0) / 3 = 14.33...
    expected_average = (42.0 + 1.0 + 0.0) / 3.0
    assert_in_delta expected_average, series.first.last, 0.01, "Different answer types should convert to numeric and be averaged correctly"
  end

  # =============================================================================
  # REBUCKETING TESTS (Daily -> Weekly conversions)
  # =============================================================================

  test "daily to weekly rebucketing aggregates correctly" do
    # Create daily metric first
    daily_metric = create_metric(width: "90_days", resolution: "day")

    # Create answers for different days within the 90-day window
    create_answer(value: 2.5, time: (@fixed_time - 10.days).beginning_of_day) # 10 days ago
    create_answer(value: 3.0, time: (@fixed_time - 5.days).beginning_of_day) # 5 days ago
    create_answer(value: 1.5, time: (@fixed_time - 1.day).beginning_of_day) # Yesterday

    # Create weekly metric that sums the daily metric
    weekly_metric = Metric.create!(
      user: @user,
      width: "90_days",
      resolution: "week",
      function: "sum",
      name: "Weekly Test Metric"
    )

    # Connect weekly metric to daily metric via MetricMetric relationship
    MetricMetric.create!(
      parent_metric: weekly_metric,
      child_metric: daily_metric
    )

    # Test daily metric shows individual days
    daily_series = daily_metric.series
    daily_values = daily_series.map { |_, value| value }.select { |v| v > 0 }
    assert_equal 3, daily_values.length, "Daily metric should show 3 running days"
    assert_includes daily_values, 2.5
    assert_includes daily_values, 3.0
    assert_includes daily_values, 1.5

    # Test weekly metric sums the week correctly
    weekly_series = weekly_metric.series
    non_zero_weekly = weekly_series.select { |_, value| value > 0 }
    weekly_total = non_zero_weekly.sum { |_, value| value }
    assert_equal 7.0, weekly_total, "Weekly total should sum all daily values (2.5 + 3.0 + 1.5 = 7.0)"
  end

  test "rebucketing handles metrics created after source data exists" do
    # This tests the specific bug scenario that was fixed

    # Step 1: Create historical answers BEFORE any metrics exist
    historical_time1 = @fixed_time - 10.days
    historical_time2 = @fixed_time - 3.days

    create_answer(value: 2.53, time: historical_time1) # 10 days ago
    create_answer(value: 3.38, time: historical_time2) # 3 days ago

    # Step 2: Create metrics AFTER the answer data exists (simulates original bug)
    daily_metric = create_metric(width: "90_days", resolution: "day")
    weekly_metric = Metric.create!(
      user: @user, width: "90_days", resolution: "week", function: "sum", name: "Late Weekly"
    )
    MetricMetric.create!(parent_metric: weekly_metric, child_metric: daily_metric)

    # Step 3: Verify both daily and weekly metrics show the historical data correctly
    daily_series = daily_metric.series
    historical_daily = daily_series.select { |date, value| value > 0 }

    assert_equal 2, historical_daily.length, "Daily metric should show both historical answers"
    daily_values = historical_daily.map { |_, value| value }
    assert_includes daily_values, 2.53
    assert_includes daily_values, 3.38

    # Step 4: Verify weekly aggregation works despite creation order
    weekly_series = weekly_metric.series
    historical_weekly = weekly_series.select { |date, value| value > 0 }

    # Should have 2 weeks with data (historical answers were 7 days apart)
    assert_equal 2, historical_weekly.length, "Weekly metric should show 2 weeks with data"
    weekly_values = historical_weekly.map { |_, value| value }
    assert_includes weekly_values, 2.53, "Should include week with 2.53 miles"
    assert_includes weekly_values, 3.38, "Should include week with 3.38 miles"
  end

  private

  def create_metric(width:, resolution:, scale: nil, wrap: "none", function: "answer")
    Metric.create!(
      user: @user,
      width: width,
      resolution: resolution,
      function: function,
      scale: scale,
      wrap: wrap,
      name: "Test Metric"
    ).tap do |metric|
      # Associate the metric with the question
      MetricQuestion.create!(metric: metric, question: @question)
    end
  end

  def create_answer(value:, time:, answer_type: "number")
    Answer.create!(
      question: @question,
      response: @response,
      user: @user,
      answer_type: answer_type,
      number_value: answer_type == "number" ? value : nil,
      bool_value: answer_type == "bool" ? value : nil,
      created_at: time
    )
  end
end
