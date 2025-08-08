require "test_helper"

class MetricSeriesCacheTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)

    # Create a test question
    @question = Question.create!(
      name: "Test Metric Question #{SecureRandom.hex(4)}",
      question_type: "number",
      user: @user
    )

    # Create a form and response for answers
    @form = Form.create!(
      user: @user,
      name: "Test Form #{SecureRandom.hex(4)}"
    )

    @response = Response.create!(
      user: @user,
      form: @form
    )

    # Freeze time to a known point for predictable tests
    @fixed_time = Time.zone.parse("2025-07-27 14:30:00")
    travel_to @fixed_time
  end

  def teardown
    travel_back
  end

  def create_metric(name:, function: "answer", resolution: "day", width: "90_days")
    Metric.create!(
      user: @user,
      name: name,
      function: function,
      resolution: resolution,
      width: width
    )
  end

  def create_answer(value:, time: @fixed_time)
    Answer.create!(
      question: @question,
      response: @response,
      user: @user,
      answer_type: "number",
      number_value: value,
      created_at: time
    )
  end

  test "cache invalidation when metric created after answers exist" do
    travel_to Time.zone.parse("2025-07-27 14:00:00") do
      # Step 1: Create historical answers BEFORE metric exists
      create_answer(value: 2.53, time: Time.zone.parse("2025-07-18 23:00:00"))
      create_answer(value: 3.38, time: Time.zone.parse("2025-07-27 12:00:00"))

      # Step 2: Create daily metric AFTER answers exist (simulates the original bug scenario)
      @daily_metric = create_metric(name: "Test Daily Miles")
      MetricQuestion.create!(metric: @daily_metric, question: @question)

      # Step 3: Create weekly metric that sums the daily metric
      @weekly_metric = create_metric(
        name: "Test Weekly Miles",
        function: "sum",
        resolution: "week"
      )
      MetricMetric.create!(parent_metric: @weekly_metric, child_metric: @daily_metric)
    end

    # Step 4: Test that cache properly invalidates and data flows correctly
    daily_series = @daily_metric.series
    july_daily = daily_series.select { |date, value|
      date.to_date >= Date.parse("2025-07-18") && date.to_date <= Date.parse("2025-07-27")
    }

    # Verify daily metric shows both values
    daily_values = july_daily.map { |_, value| value }.compact.select { |v| v > 0 }
    assert_equal 2, daily_values.length, "Daily metric should show both running days"
    assert_includes daily_values, 2.53
    assert_includes daily_values, 3.38

    # Step 5: Test weekly aggregation works correctly
    weekly_series = @weekly_metric.series
    july_weekly = weekly_series.select { |date, value|
      date.to_date >= Date.parse("2025-07-14") && date.to_date <= Date.parse("2025-08-04")
    }

    # Verify weekly metric sums the daily values correctly
    weekly_values = july_weekly.map { |_, value| value }.compact.select { |v| v > 0 }
    assert_equal 2, weekly_values.length, "Weekly metric should show two weeks with running"
    assert_includes weekly_values, 2.53, "Week containing July 18 should show 2.53"
    assert_includes weekly_values, 3.38, "Week containing July 27 should show 3.38"
  end

  test "fresh? method considers source data timestamps" do
    # Test that cache considers source data timestamps for freshness

    # Create metric and answer at same time
    metric = create_metric(name: "Test Metric")
    MetricQuestion.create!(metric: metric, question: @question)

    create_answer(value: 5.0, time: @fixed_time)
    metric.series  # This creates the cache

    cache = metric.metric_series_cache

    # The key test: if we add newer source data, cache should become stale
    create_answer(value: 8.0, time: @fixed_time + 1.hour)

    cache.reload
    refute cache.fresh?, "Cache should be stale when newer source data exists"
  end

  test "cache invalidation cascade through metric dependencies" do
    # Test that cache invalidation flows through metric dependencies

    # Create daily metric (level 1: Question -> Daily)
    daily_metric = create_metric(name: "Daily Test")
    MetricQuestion.create!(metric: daily_metric, question: @question)

    # Create weekly metric (level 2: Daily -> Weekly)
    weekly_metric = create_metric(name: "Weekly Test", function: "sum", resolution: "week")
    MetricMetric.create!(parent_metric: weekly_metric, child_metric: daily_metric)

    # Create base data and generate caches
    create_answer(value: 3.0, time: @fixed_time)

    daily_series = daily_metric.series
    weekly_series = weekly_metric.series

    daily_cache = daily_metric.metric_series_cache
    weekly_cache = weekly_metric.metric_series_cache

    # Add new answer - should invalidate both caches through dependency chain
    create_answer(value: 4.0, time: @fixed_time + 1.hour)

    # Reload caches if they still exist (they might have been destroyed by invalidation)
    daily_cache = daily_metric.metric_series_cache
    weekly_cache = weekly_metric.metric_series_cache

    if daily_cache
      refute daily_cache.fresh?, "Daily cache should be stale after new answer"
    end

    if weekly_cache
      refute weekly_cache.fresh?, "Weekly cache should be stale due to stale dependency"
    end
  end

  test "rebucketing handles daily to weekly conversion correctly" do
    # Test the specific bug that was fixed

    # Create daily answers
    create_answer(value: 2.5, time: Time.zone.parse("2025-07-18 23:00:00"))  # Friday
    create_answer(value: 3.0, time: Time.zone.parse("2025-07-21 23:00:00"))  # Monday (start of new week)
    create_answer(value: 4.5, time: Time.zone.parse("2025-07-25 23:00:00"))  # Friday same week as Monday

    # Create daily metric
    daily_metric = create_metric(name: "Daily", resolution: "day")
    MetricQuestion.create!(metric: daily_metric, question: @question)

    # Create weekly metric that sums daily
    weekly_metric = create_metric(name: "Weekly", function: "sum", resolution: "week")
    MetricMetric.create!(parent_metric: weekly_metric, child_metric: daily_metric)

    # Get weekly data
    weekly_series = weekly_metric.series
    july_weeks = weekly_series.select { |date, value|
      date.to_date >= Date.parse("2025-07-14") && date.to_date <= Date.parse("2025-07-28")
    }

    # Should have exactly 2 weeks with data
    non_zero_weeks = july_weeks.select { |_, value| value > 0 }
    assert_equal 2, non_zero_weeks.length, "Should have 2 weeks with running data"

    # Week containing July 18 (Fri) should have 2.5
    week_1_value = july_weeks.find { |date, _| date.to_date == Date.parse("2025-07-14") }&.last
    assert_equal 2.5, week_1_value, "Week of July 14 should contain Friday's 2.5 miles"

    # Week containing July 21 (Mon) and July 25 (Fri) should sum to 7.5
    week_2_value = july_weeks.find { |date, _| date.to_date == Date.parse("2025-07-21") }&.last
    assert_equal 7.5, week_2_value, "Week of July 21 should sum Monday (3.0) + Friday (4.5) = 7.5"
  end

  test "cache handles entity creation order independence" do
    # Test that metrics work regardless of creation order of questions/answers/metrics

    travel_to Time.zone.parse("2025-07-20 10:00:00") do
      # Test scenario: Question -> Answers -> Metric (the bug we fixed)
      question = Question.create!(name: "Order Test Q", question_type: "number", user: @user)

      # Create answer BEFORE metric
      Answer.create!(
        question: question,
        response: @response,
        user: @user,
        answer_type: "number",
        number_value: 2.5,
        created_at: Time.zone.parse("2025-07-20 09:00:00")
      )

      # Create metric AFTER answer exists
      metric = create_metric(name: "Order Test M")
      MetricQuestion.create!(metric: metric, question: question)

      # Verify the metric can see the historical answer data
      series = metric.series
      non_zero_values = series.select { |_, value| value && value > 0 }

      assert non_zero_values.any?, "Metric created after answers should still see historical data"
      assert_includes non_zero_values.map(&:last), 2.5, "Should include the 2.5 value from historical answer"

      # Cache should exist (created when we called .series)
      cache = metric.metric_series_cache
      assert cache, "Cache should exist"
    end
  end
end
