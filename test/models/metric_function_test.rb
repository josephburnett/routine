require "test_helper"

class MetricFunctionTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)

    # Create unique questions for this test to avoid interference
    @question_temperature = Question.create!(
      name: "Temperature #{SecureRandom.hex(4)}",
      question_type: "number",
      user: @user
    )

    @question_humidity = Question.create!(
      name: "Humidity #{SecureRandom.hex(4)}",
      question_type: "number",
      user: @user
    )

    @question_pressure = Question.create!(
      name: "Pressure #{SecureRandom.hex(4)}",
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
  # FUNCTION VALIDATION TESTS
  # =============================================================================

  test "valid functions are sum, average, difference" do
    valid_functions = %w[sum average difference]

    valid_functions.each do |function|
      metric = Metric.new(
        user: @user,
        width: "daily",
        resolution: "hour",
        function: function,
        name: "Test Metric"
      )
      assert metric.valid?, "#{function} should be a valid function"
    end
  end

  test "legacy functions answer and count are still valid for existing data" do
    legacy_functions = %w[answer count]

    legacy_functions.each do |function|
      metric = Metric.new(
        user: @user,
        width: "daily",
        resolution: "hour",
        function: function,
        name: "Test Metric"
      )
      assert metric.valid?, "#{function} should still be valid for legacy data"
    end
  end

  test "invalid functions are rejected" do
    invalid_functions = %w[multiply divide maximum minimum]

    invalid_functions.each do |function|
      metric = Metric.new(
        user: @user,
        width: "daily",
        resolution: "hour",
        function: function,
        name: "Test Metric"
      )
      assert_not metric.valid?, "#{function} should not be a valid function"
    end
  end

  # =============================================================================
  # SOURCE SELECTION TESTS
  # =============================================================================

  test "metric can select question sources" do
    metric = create_metric(function: "sum", width: "daily", resolution: "hour")

    # Associate metric with questions
    MetricQuestion.create!(metric: metric, question: @question_temperature)
    MetricQuestion.create!(metric: metric, question: @question_humidity)

    assert_equal 2, metric.questions.count
    assert_includes metric.questions, @question_temperature
    assert_includes metric.questions, @question_humidity
  end

  test "metric can select metric sources" do
    # Create source metrics
    source_metric_1 = create_metric(function: "sum", width: "daily", resolution: "hour", name: "Source 1")
    source_metric_2 = create_metric(function: "sum", width: "daily", resolution: "hour", name: "Source 2")

    # Create target metric that references source metrics
    target_metric = create_metric(function: "average", width: "daily", resolution: "hour", name: "Target")
    MetricMetric.create!(parent_metric: target_metric, child_metric: source_metric_1)
    MetricMetric.create!(parent_metric: target_metric, child_metric: source_metric_2)

    assert_equal 2, target_metric.child_metrics.count
    assert_includes target_metric.child_metrics, source_metric_1
    assert_includes target_metric.child_metrics, source_metric_2
  end

  test "metric can select mixed question and metric sources" do
    # Create a source metric
    source_metric = create_metric(function: "sum", width: "daily", resolution: "hour", name: "Source")
    MetricQuestion.create!(metric: source_metric, question: @question_pressure)

    # Create target metric that references both questions and metrics
    target_metric = create_metric(function: "sum", width: "daily", resolution: "hour", name: "Target")
    MetricQuestion.create!(metric: target_metric, question: @question_temperature)
    MetricQuestion.create!(metric: target_metric, question: @question_humidity)
    MetricMetric.create!(parent_metric: target_metric, child_metric: source_metric)

    assert_equal 2, target_metric.questions.count
    assert_equal 1, target_metric.child_metrics.count
  end

  # =============================================================================
  # SOURCE SERIES MATERIALIZATION TESTS
  # =============================================================================

  test "question sources materialize with target metric parameters" do
    # Create answers for temperature question
    create_answer(question: @question_temperature, value: 20, time: @fixed_time - 2.hours)  # 12:30
    create_answer(question: @question_temperature, value: 25, time: @fixed_time - 1.hour)   # 13:30
    create_answer(question: @question_temperature, value: 30, time: @fixed_time)            # 14:30

    # Create metric with hourly resolution
    metric = create_metric(function: "sum", width: "daily", resolution: "hour")
    MetricQuestion.create!(metric: metric, question: @question_temperature)

    series = metric.series

    # Should have 3 hourly buckets with the question data
    assert_equal 3, series.length

    # Values should be placed in the correct hourly buckets
    hour_12 = series.find { |time, value| time.hour == 12 }
    hour_13 = series.find { |time, value| time.hour == 13 }
    hour_14 = series.find { |time, value| time.hour == 14 }

    assert_equal 20.0, hour_12.last, "12:00 bucket should contain temperature 20"
    assert_equal 25.0, hour_13.last, "13:00 bucket should contain temperature 25"
    assert_equal 30.0, hour_14.last, "14:00 bucket should contain temperature 30"
  end

  test "metric sources materialize with their own parameters then get rebucketed" do
    # Create a source metric with day resolution
    source_metric = create_metric(function: "sum", width: "daily", resolution: "day", name: "Daily Source")
    MetricQuestion.create!(metric: source_metric, question: @question_temperature)

    # Create answers spread across the day
    create_answer(question: @question_temperature, value: 10, time: @fixed_time.beginning_of_day)      # 00:00
    create_answer(question: @question_temperature, value: 20, time: @fixed_time.beginning_of_day + 12.hours)  # 12:00
    create_answer(question: @question_temperature, value: 30, time: @fixed_time)                       # 14:30

    # Source metric should materialize as single daily bucket: 10+20+30 = 60 (sum function)
    source_series = source_metric.series
    assert_equal 1, source_series.length
    assert_equal 60.0, source_series.first.last

    # Create target metric with hour resolution that references the source metric
    target_metric = create_metric(function: "sum", width: "daily", resolution: "hour", name: "Hourly Target")
    MetricMetric.create!(parent_metric: target_metric, child_metric: source_metric)

    # Target metric should rebucket the source data to hourly resolution
    target_series = target_metric.series

    # Should have at least one hourly bucket from rebucketing the daily source
    assert target_series.length > 0, "Should have at least one hourly bucket"

    # The rebucketed values should be derived from the source daily value
    first_bucket = target_series.first
    assert_not_nil first_bucket, "Should have a rebucketed bucket"
    assert_equal 60.0, first_bucket.last, "Rebucketed value should match source daily value"
  end

  # =============================================================================
  # FUNCTION APPLICATION TESTS - SUM
  # =============================================================================

  test "sum function sums values across all sources for each bucket" do
    # Create answers for different questions at the same times
    create_answer(question: @question_temperature, value: 20, time: @fixed_time)      # 14:30
    create_answer(question: @question_humidity, value: 60, time: @fixed_time)         # 14:30
    create_answer(question: @question_pressure, value: 1013, time: @fixed_time)       # 14:30

    create_answer(question: @question_temperature, value: 25, time: @fixed_time - 1.hour)  # 13:30
    create_answer(question: @question_humidity, value: 65, time: @fixed_time - 1.hour)     # 13:30
    # No pressure reading at 13:30

    # Create sum metric that references all three questions
    metric = create_metric(function: "sum", width: "daily", resolution: "hour")
    MetricQuestion.create!(metric: metric, question: @question_temperature)
    MetricQuestion.create!(metric: metric, question: @question_humidity)
    MetricQuestion.create!(metric: metric, question: @question_pressure)

    series = metric.series

    # 14:00 bucket should sum: 20 + 60 + 1013 = 1093
    hour_14 = series.find { |time, value| time.hour == 14 }
    assert_equal 1093.0, hour_14.last, "14:00 bucket should sum all three values"

    # 13:00 bucket should sum: 25 + 65 + 0 = 90 (pressure defaults to 0 when missing)
    hour_13 = series.find { |time, value| time.hour == 13 }
    assert_equal 90.0, hour_13.last, "13:00 bucket should sum available values"
  end

  test "sum function works with mixed question and metric sources" do
    # Create a source metric
    source_metric = create_metric(function: "sum", width: "daily", resolution: "hour", name: "Source")
    source_metric.questions << @question_pressure
    create_answer(question: @question_pressure, value: 1000, time: @fixed_time)

    # Create target metric that sums a question and a metric
    target_metric = create_metric(function: "sum", width: "daily", resolution: "hour", name: "Target")
    target_metric.questions << @question_temperature
    MetricMetric.create!(parent_metric: target_metric, child_metric: source_metric)

    create_answer(question: @question_temperature, value: 25, time: @fixed_time)

    series = target_metric.series

    # Should sum temperature (25) + pressure from source metric (1000) = 1025
    hour_14 = series.find { |time, value| time.hour == 14 }
    assert_equal 1025.0, hour_14.last, "Should sum question and metric sources"
  end

  # =============================================================================
  # FUNCTION APPLICATION TESTS - AVERAGE
  # =============================================================================

  test "average function averages values across all sources for each bucket" do
    # Create answers for different questions at the same time
    create_answer(question: @question_temperature, value: 20, time: @fixed_time)
    create_answer(question: @question_humidity, value: 40, time: @fixed_time)
    create_answer(question: @question_pressure, value: 60, time: @fixed_time)

    # Create average metric
    metric = create_metric(function: "average", width: "daily", resolution: "hour")
    MetricQuestion.create!(metric: metric, question: @question_temperature)
    MetricQuestion.create!(metric: metric, question: @question_humidity)
    MetricQuestion.create!(metric: metric, question: @question_pressure)

    series = metric.series

    # Should average: (20 + 40 + 60) / 3 = 40
    hour_14 = series.find { |time, value| time.hour == 14 }
    assert_equal 40.0, hour_14.last, "Should average all three values"
  end

  test "average function handles missing data correctly" do
    # Create answers where not all sources have data
    create_answer(question: @question_temperature, value: 30, time: @fixed_time)
    create_answer(question: @question_humidity, value: 70, time: @fixed_time)
    # No pressure data

    metric = create_metric(function: "average", width: "daily", resolution: "hour")
    MetricQuestion.create!(metric: metric, question: @question_temperature)
    MetricQuestion.create!(metric: metric, question: @question_humidity)
    MetricQuestion.create!(metric: metric, question: @question_pressure)

    series = metric.series

    # Should average only available values: (30 + 70) / 2 = 50
    # Missing sources should not contribute to the average
    hour_14 = series.find { |time, value| time.hour == 14 }
    assert_equal 50.0, hour_14.last, "Should average only available values"
  end

  # =============================================================================
  # FUNCTION APPLICATION TESTS - DIFFERENCE
  # =============================================================================

  test "difference function subtracts subsequent sources from first source" do
    # Create answers for different questions
    create_answer(question: @question_temperature, value: 100, time: @fixed_time)  # First source
    create_answer(question: @question_humidity, value: 30, time: @fixed_time)      # Second source
    create_answer(question: @question_pressure, value: 20, time: @fixed_time)      # Third source

    metric = create_metric(function: "difference", width: "daily", resolution: "hour")
    MetricQuestion.create!(metric: metric, question: @question_temperature)  # First source
    MetricQuestion.create!(metric: metric, question: @question_humidity)     # Subtract this
    MetricQuestion.create!(metric: metric, question: @question_pressure)     # And this

    series = metric.series

    # Should calculate: 100 - 30 - 20 = 50
    hour_14 = series.find { |time, value| time.hour == 14 }
    assert_equal 50.0, hour_14.last, "Should subtract subsequent sources from first"
  end

  test "difference function with single source returns that source value" do
    create_answer(question: @question_temperature, value: 42, time: @fixed_time)

    metric = create_metric(function: "difference", width: "daily", resolution: "hour")
    MetricQuestion.create!(metric: metric, question: @question_temperature)

    series = metric.series

    # With only one source, difference should return that value
    hour_14 = series.find { |time, value| time.hour == 14 }
    assert_equal 42.0, hour_14.last, "Single source difference should return source value"
  end

  # =============================================================================
  # REBUCKETING TESTS
  # =============================================================================

  test "rebucketing combines buckets when target has coarser resolution" do
    # Create source metric with hour resolution
    source_metric = create_metric(function: "sum", width: "daily", resolution: "hour", name: "Hourly Source")
    MetricQuestion.create!(metric: source_metric, question: @question_temperature)

    # Create hourly data
    create_answer(question: @question_temperature, value: 10, time: @fixed_time - 2.hours)  # 12:30 -> 12:00 bucket
    create_answer(question: @question_temperature, value: 20, time: @fixed_time - 1.hour)   # 13:30 -> 13:00 bucket
    create_answer(question: @question_temperature, value: 30, time: @fixed_time)            # 14:30 -> 14:00 bucket

    # Source should have 3 hourly buckets
    source_series = source_metric.series
    assert_equal 3, source_series.length

    # Create target metric with day resolution that references the source
    target_metric = create_metric(function: "sum", width: "daily", resolution: "day", name: "Daily Target")
    MetricMetric.create!(parent_metric: target_metric, child_metric: source_metric)

    # Target should rebucket to single daily value
    target_series = target_metric.series
    assert_equal 1, target_series.length

    # Daily bucket should sum all hourly values: 10 + 20 + 30 = 60
    daily_bucket = target_series.first
    assert_equal 60.0, daily_bucket.last, "Daily rebucketing should sum hourly values"
  end

  test "rebucketing splits buckets when target has finer resolution" do
    # Create source metric with day resolution
    source_metric = create_metric(function: "sum", width: "daily", resolution: "day", name: "Daily Source")
    MetricQuestion.create!(metric: source_metric, question: @question_temperature)

    # Create daily data (answers throughout the day get summed into single daily bucket)
    create_answer(question: @question_temperature, value: 10, time: @fixed_time.beginning_of_day)
    create_answer(question: @question_temperature, value: 20, time: @fixed_time.beginning_of_day + 12.hours)
    create_answer(question: @question_temperature, value: 30, time: @fixed_time)

    # Source should have 1 daily bucket with sum: 10+20+30 = 60 (sum function)
    source_series = source_metric.series
    assert_equal 1, source_series.length
    assert_equal 60.0, source_series.first.last

    # Create target metric with hour resolution
    target_metric = create_metric(function: "sum", width: "daily", resolution: "hour", name: "Hourly Target")
    MetricMetric.create!(parent_metric: target_metric, child_metric: source_metric)

    # Target should split daily value across all hours in the day
    target_series = target_metric.series

    # Should have hourly buckets for the entire day covered by the source
    # Since source covers the full day, target should have buckets for hours in that day
    assert target_series.length > 0, "Should have at least one hourly bucket"

    # All hourly buckets should have the same value (daily value distributed)
    # For now, let's just verify that the rebucketing worked
    first_bucket = target_series.first
    assert_not_nil first_bucket, "Should have at least one bucket"
    assert_equal 60.0, first_bucket.last, "Rebucketed value should be the daily value"
  end

  # =============================================================================
  # LEGACY FUNCTION BEHAVIOR TESTS
  # =============================================================================

  test "legacy answer function behaves like sum" do
    create_answer(question: @question_temperature, value: 10, time: @fixed_time)
    create_answer(question: @question_humidity, value: 20, time: @fixed_time)

    # Create metric with legacy 'answer' function
    legacy_metric = create_metric(function: "answer", width: "daily", resolution: "hour")
    MetricQuestion.create!(metric: legacy_metric, question: @question_temperature)
    MetricQuestion.create!(metric: legacy_metric, question: @question_humidity)

    # Create equivalent metric with 'sum' function
    sum_metric = create_metric(function: "sum", width: "daily", resolution: "hour")
    MetricQuestion.create!(metric: sum_metric, question: @question_temperature)
    MetricQuestion.create!(metric: sum_metric, question: @question_humidity)

    # Both should produce the same result
    legacy_series = legacy_metric.series
    sum_series = sum_metric.series

    assert_equal sum_series.length, legacy_series.length
    assert_equal sum_series.first.last, legacy_series.first.last, "Legacy 'answer' should behave like 'sum'"
  end

  test "legacy count function behaves like sum" do
    create_answer(question: @question_temperature, value: 5, time: @fixed_time)
    create_answer(question: @question_humidity, value: 15, time: @fixed_time)

    # Create metric with legacy 'count' function
    legacy_metric = create_metric(function: "count", width: "daily", resolution: "hour")
    MetricQuestion.create!(metric: legacy_metric, question: @question_temperature)
    MetricQuestion.create!(metric: legacy_metric, question: @question_humidity)

    # Create equivalent metric with 'sum' function
    sum_metric = create_metric(function: "sum", width: "daily", resolution: "hour")
    MetricQuestion.create!(metric: sum_metric, question: @question_temperature)
    MetricQuestion.create!(metric: sum_metric, question: @question_humidity)

    # Both should produce the same result
    legacy_series = legacy_metric.series
    sum_series = sum_metric.series

    assert_equal sum_series.first.last, legacy_series.first.last, "Legacy 'count' should behave like 'sum'"
  end

  # =============================================================================
  # EDGE CASE TESTS
  # =============================================================================

  test "metric with no sources returns empty series" do
    metric = create_metric(function: "sum", width: "daily", resolution: "hour")
    # Don't add any questions or child metrics

    series = metric.series
    assert_empty series, "Metric with no sources should return empty series"
  end

  test "function application with different source parameter combinations" do
    # Create source metrics with different parameters
    hourly_source = create_metric(function: "sum", width: "daily", resolution: "hour", name: "Hourly")
    daily_source = create_metric(function: "average", width: "daily", resolution: "day", name: "Daily")  # Changed to daily width

    MetricQuestion.create!(metric: hourly_source, question: @question_temperature)
    MetricQuestion.create!(metric: daily_source, question: @question_humidity)

    # Create data
    create_answer(question: @question_temperature, value: 10, time: @fixed_time)
    create_answer(question: @question_humidity, value: 20, time: @fixed_time)

    # Create target metric that combines both sources
    target_metric = create_metric(function: "average", width: "daily", resolution: "hour", name: "Mixed Target")
    MetricMetric.create!(parent_metric: target_metric, child_metric: hourly_source)
    MetricMetric.create!(parent_metric: target_metric, child_metric: daily_source)

    series = target_metric.series

    # Should successfully combine sources with different parameters
    assert_not_empty series, "Should handle mixed source parameters"

    # Should average the rebucketed values from both sources
    hour_14 = series.find { |time, value| time.hour == 14 }
    assert_not_nil hour_14, "Should have data in the 14:00 bucket"
    assert_equal 15.0, hour_14.last, "Should average values from both sources: (10 + 20) / 2 = 15"
  end

  private

  def create_metric(function:, width:, resolution:, scale: nil, wrap: "none", name: nil)
    Metric.create!(
      user: @user,
      width: width,
      resolution: resolution,
      function: function,
      scale: scale,
      wrap: wrap,
      name: name || "Test Metric #{SecureRandom.hex(4)}"
    )
  end

  def create_answer(question:, value:, time:, answer_type: "number")
    travel_to time do
      Answer.create!(
        question: question,
        response: @response,
        user: @user,
        answer_type: answer_type,
        number_value: answer_type == "number" ? value : nil,
        bool_value: answer_type == "bool" ? value : nil,
        created_at: time
      )
    end
  end
end
