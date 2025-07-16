class Metric < ApplicationRecord
  include Namespaceable

  belongs_to :user

  # One-to-many relationships
  has_many :alerts, dependent: :destroy
  has_one :metric_series_cache, dependent: :destroy

  # Many-to-many relationships
  has_many :report_metrics, dependent: :destroy
  has_many :reports, through: :report_metrics

  has_many :metric_questions, dependent: :destroy
  has_many :questions, through: :metric_questions

  has_many :parent_metric_metrics, class_name: "MetricMetric", foreign_key: "child_metric_id", dependent: :destroy
  has_many :parent_metrics, through: :parent_metric_metrics, source: :parent_metric

  has_many :child_metric_metrics, class_name: "MetricMetric", foreign_key: "parent_metric_id", dependent: :destroy

  belongs_to :first_metric, class_name: "Metric", optional: true

  validates :resolution, presence: true, inclusion: { in: %w[five_minute hour day week month] }
  validates :width, presence: true, inclusion: { in: %w[daily weekly monthly 90_days yearly 7_days 30_days all_time] }
  validates :function, presence: true, inclusion: { in: %w[answer sum average difference count] }
  validates :wrap, inclusion: { in: %w[none hour day weekly] }, allow_nil: true, allow_blank: true
  validates :scale, numericality: { greater_than: 0 }, allow_nil: true
  validates :fill, inclusion: { in: %w[none zero linear previous] }, allow_nil: true

  attr_accessor :child_metric_ids_temp, :child_metric_ids_changed

  # Convert empty string to nil for wrap field
  def wrap=(value)
    super(value.presence)
  end

  before_save :store_child_metric_ids
  after_save :create_child_associations

  scope :not_deleted, -> { where(deleted: false) }

  after_update :invalidate_dependent_caches
  after_destroy :invalidate_dependent_caches

  def soft_delete!
    update!(deleted: true)
  end

  def type
    case function
    when "answer"
      # Return the most common question type from referenced questions
      question_types = questions.pluck(:question_type).uniq
      question_types.first || "number"
    else
      "number" # All calculated metrics return numbers
    end
  end

  def series
    # Use cached data if available and fresh
    if metric_series_cache&.fresh?
      return metric_series_cache.series_data || []
    end

    # Otherwise calculate, cache, and return
    calculated_series = calculate_series_uncached
    MetricSeriesCache.update_for_metric(self)
    calculated_series
  end

  def calculate_series_uncached
    # Legacy support - answer and count functions now behave like sum
    if function == "answer" || function == "count"
      # Use new sum behavior for legacy functions
      source_series_list = collect_all_source_series
      rebucketed_sources = rebucket_sources_to_target_parameters(source_series_list)
      return apply_function_across_sources_with_function(rebucketed_sources, "sum")
    end

    # New behavior for sum, average, difference functions
    # 1. Collect all source series (Questions and Metrics)
    source_series_list = collect_all_source_series

    # 2. Rebucket all sources to match this metric's parameters
    rebucketed_sources = rebucket_sources_to_target_parameters(source_series_list)

    # 3. Apply the function across sources for each bucket
    apply_function_across_sources(rebucketed_sources)
  end

  def child_metric_ids=(ids)
    @child_metric_ids_temp = Array(ids).reject(&:blank?)
    @child_metric_ids_changed = true
  end

  def child_metric_ids
    if persisted?
      child_metric_metrics.pluck(:child_metric_id)
    else
      @child_metric_ids_temp || []
    end
  end

  def child_metrics
    if persisted?
      Metric.where(id: child_metric_metrics.pluck(:child_metric_id))
    else
      Metric.where(id: @child_metric_ids_temp || [])
    end
  end

  def display_name
    if name.present?
      name
    else
      id_display = id ? "##{id}" : "(New)"
      "Metric #{id_display}"
    end
  end

  private

  def collect_all_source_series
    source_series = []

    # Collect series from Question sources (these are already in target parameters)
    questions.each do |question|
      question_series = generate_question_series(question)
      source_series << { type: :question, series: question_series } unless question_series.empty?
    end

    # Collect series from Metric sources (these need rebucketing)
    child_metrics.each do |child_metric|
      metric_series = child_metric.series
      source_series << { type: :metric, series: metric_series } unless metric_series.empty?
    end

    source_series
  end

  def rebucket_sources_to_target_parameters(source_series_list)
    return [] if source_series_list.empty?

    # Generate target time buckets based on this metric's parameters
    target_buckets = generate_time_buckets

    # Process each source series based on its type
    source_series_list.map do |source_info|
      if source_info[:type] == :question
        # Question sources are already in target parameters - no rebucketing needed
        source_info[:series]
      else
        # Metric sources need rebucketing to match target parameters
        rebucket_series_to_target_buckets(source_info[:series], target_buckets)
      end
    end
  end

  def apply_function_across_sources(rebucketed_sources)
    apply_function_across_sources_with_function(rebucketed_sources, function)
  end

  def apply_function_across_sources_with_function(rebucketed_sources, target_function)
    return [] if rebucketed_sources.empty?

    # Get all unique time buckets from all sources
    all_bucket_times = rebucketed_sources.flat_map { |series| series.map(&:first) }.uniq.sort

    # For each time bucket, apply the function across all sources
    raw_series = all_bucket_times.map do |bucket_time|
      # Get values from each source for this time bucket
      source_values = rebucketed_sources.map do |series|
        bucket = series.find { |time, value| time == bucket_time }
        bucket ? bucket.last : nil
      end

      # Remove nil values (sources that don't have data for this bucket)
      available_values = source_values.compact

      # Apply the function
      if available_values.empty?
        # If no sources have data for this bucket, return nil
        [ bucket_time, nil ]
      else
        result_value = case target_function
        when "sum"
          available_values.sum
        when "average"
          available_values.sum.to_f / available_values.size
        when "difference"
          # First value minus all subsequent values
          available_values.first - available_values[1..-1].sum
        end

        [ bucket_time, result_value ]
      end
    end

    # Apply fill logic to the raw series
    apply_fill_logic(raw_series)
  end

  def generate_question_series(question)
    # Generate series for a single question using this metric's parameters
    filtered_answers = Answer.joins(:response, :question)
                             .where(questions: { id: question.id })
                             .where(responses: { user_id: user_id })
                             .where(created_at: time_range)
                             .order(:created_at)

    return [] if filtered_answers.empty?

    # Use the same logic as generate_answer_series but for a single question
    if wrap.present? && wrap != "none"
      # Wrap logic for single question
      wrapped_data = filtered_answers.map do |answer|
        value = numeric_value(answer)
        scaled_value = value * (scale || 1.0)
        wrapped_timestamp = wrap_timestamp(answer.created_at)
        [ wrapped_timestamp, scaled_value ]
      end

      grouped_wrapped = wrapped_data.group_by(&:first)
      grouped_wrapped.map do |wrapped_time, time_value_pairs|
        values = time_value_pairs.map(&:last)
        averaged_value = values.sum.to_f / values.size
        [ wrapped_time, averaged_value ]
      end.sort_by(&:first)
    else
      # Normal bucketing logic for single question
      grouped_answers = group_by_resolution(filtered_answers)
      all_buckets = generate_time_buckets

      # Generate raw series data with actual values
      raw_series = all_buckets.map do |bucket_time|
        if grouped_answers.has_key?(bucket_time)
          group_answers = grouped_answers[bucket_time]
          values = group_answers.map { |answer| numeric_value(answer) }
          value = values.sum.to_f / values.size
          scaled_value = value * (scale || 1.0)
          [ bucket_time, scaled_value ]
        else
          [ bucket_time, nil ]
        end
      end

      # Apply fill logic
      apply_fill_logic(raw_series)
    end
  end

  def rebucket_series_to_target_buckets(source_series, target_buckets)
    return [] if source_series.empty? || target_buckets.empty?

    # For each target bucket, find source values that apply to it
    target_buckets.map do |target_bucket_start|
      target_bucket_end = next_bucket_start(target_bucket_start)

      applicable_values = []

      source_series.each do |source_time, source_value|
        # Simple overlap detection: check if target bucket overlaps with source data
        # This handles both directions: finer->coarser and coarser->finer

        # Case 1: Exact time match
        if source_time == target_bucket_start
          applicable_values << source_value
        # Case 2: Source at start of day, target is hourly within that day
        elsif source_time.hour == 0 && source_time.min == 0 && source_time.sec == 0 &&
              target_bucket_start.to_date == source_time.to_date
          # Daily source applies to hourly targets in same day
          applicable_values << source_value
        # Case 3: Source is hourly, target is daily for same day
        elsif target_bucket_start.hour == 0 && target_bucket_start.min == 0 && target_bucket_start.sec == 0 &&
              source_time.to_date == target_bucket_start.to_date
          # Hourly source contributes to daily target
          applicable_values << source_value
        end
      end

      if applicable_values.any?
        # Use first value for daily->hourly (same value distributed)
        # Sum values for hourly->daily (combine values)
        if target_bucket_start.hour == 0 && target_bucket_start.min == 0 && target_bucket_start.sec == 0
          # Target is daily - sum the hourly values
          total_value = applicable_values.sum
        else
          # Target is hourly - use the daily value
          total_value = applicable_values.first
        end
        [ target_bucket_start, total_value ]
      else
        nil
      end
    end.compact
  end


  def wrap_timestamp(timestamp)
    # Map timestamp to position within the wrap period
    base_date = Date.current

    case wrap
    when "hour"
      # Map to position within a reference hour (0-59 minutes)
      base_date.beginning_of_day + timestamp.min.minutes + timestamp.sec.seconds
    when "day"
      # Map to position within a reference day (0-23:59:59)
      base_date.beginning_of_day + timestamp.hour.hours + timestamp.min.minutes + timestamp.sec.seconds
    when "weekly"
      # Map to position within a reference week (0-6 days, 0-23:59:59)
      # Convert wday (0=Sunday, 1=Monday, ...) to days from Monday start
      days_from_monday = timestamp.wday == 0 ? 6 : timestamp.wday - 1
      base_date.beginning_of_week + days_from_monday.days + timestamp.hour.hours + timestamp.min.minutes + timestamp.sec.seconds
    else
      timestamp
    end
  end

  def generate_answer_series
    # Get all answers to the referenced questions
    filtered_answers = Answer.joins(:response, :question)
                             .where(questions: { id: questions.pluck(:id) })
                             .where(responses: { user_id: user_id })
                             .where(created_at: time_range)
                             .order(:created_at)

    # If wrapping is enabled, map timestamps first, then group and average
    if wrap.present? && wrap != "none"
      # Get raw data points with wrapped timestamps
      wrapped_data = filtered_answers.map do |answer|
        value = numeric_value(answer)
        scaled_value = value * (scale || 1.0)
        wrapped_timestamp = wrap_timestamp(answer.created_at)
        [ wrapped_timestamp, scaled_value ]
      end

      # Group by wrapped timestamp and average overlapping values
      grouped_wrapped = wrapped_data.group_by(&:first)
      grouped_wrapped.map do |wrapped_time, time_value_pairs|
        values = time_value_pairs.map(&:last)
        averaged_value = values.sum.to_f / values.size
        [ wrapped_time, averaged_value ]
      end.sort_by(&:first)
    else
      # Use bucketing for non-wrapped data
      grouped_answers = group_by_resolution(filtered_answers)

      # Generate all time buckets in the range
      all_buckets = generate_time_buckets

      # Generate raw series data with actual values
      raw_series = all_buckets.map do |bucket_time|
        if grouped_answers.has_key?(bucket_time)
          # Bucket has data - calculate average
          group_answers = grouped_answers[bucket_time]
          values = group_answers.map { |answer| numeric_value(answer) }
          value = values.sum.to_f / values.size

          # Apply scale factor for answer metrics
          scaled_value = value * (scale || 1.0)
          [ bucket_time, scaled_value ]
        else
          [ bucket_time, nil ]
        end
      end

      # Apply fill logic
      apply_fill_logic(raw_series)
    end
  end

  def generate_sum_series
    # Sum all child metric values for each time bucket
    combine_metric_series { |values| values.sum }
  end

  def generate_average_series
    # Average all child metric values for each time bucket
    combine_metric_series { |values| values.empty? ? 0 : values.sum.to_f / values.size }
  end

  def generate_difference_series
    # Take first metric's values and subtract all others
    return [] if child_metrics.empty?

    # If first_metric is specified, use it; otherwise use first child metric
    primary_metric = first_metric || child_metrics.first
    other_metrics = child_metrics.where.not(id: primary_metric.id)

    # Get series from primary and other metrics
    primary_series = primary_metric.series
    other_series = other_metrics.map(&:series)

    # Generate time buckets based on this metric's resolution
    time_buckets = generate_time_buckets

    time_buckets.map do |bucket_start|
      # Get primary metric value for this time bucket
      primary_value = primary_series.select { |time_key, value|
        time_key >= bucket_start && time_key < next_bucket_start(bucket_start)
      }.sum { |time_key, value| value }

      # Get sum of all other metrics for this time bucket
      other_values = other_series.map do |series|
        series.select { |time_key, value|
          time_key >= bucket_start && time_key < next_bucket_start(bucket_start)
        }.sum { |time_key, value| value }
      end

      difference_value = primary_value - other_values.sum
      [ bucket_start, difference_value ]
    end
  end

  def generate_count_series
    # Count non-zero values from child metrics for each time bucket
    combine_metric_series { |values| values.count { |v| v != 0 } }
  end


  def combine_metric_series(&block)
    return [] if child_metrics.empty?

    # Get series from all child metrics
    all_series = child_metrics.map(&:series)
    return [] if all_series.empty?

    # Generate time buckets based on this metric's resolution and time range
    time_buckets = generate_time_buckets

    # For each time bucket, combine values from all child metrics
    time_buckets.map do |bucket_start|
      values = all_series.map do |series|
        # Sum all values from child series that fall within this time bucket
        bucket_value = series.select { |time_key, value|
          time_key >= bucket_start && time_key < next_bucket_start(bucket_start)
        }.sum { |time_key, value| value }

        bucket_value
      end

      combined_value = block.call(values)
      [ bucket_start, combined_value ]
    end
  end

  def time_range
    case width
    when "daily"
      Time.current.beginning_of_day..Time.current
    when "weekly"
      Time.current.beginning_of_week(:saturday)..Time.current
    when "monthly"
      Time.current.beginning_of_month..Time.current
    when "90_days"
      90.days.ago.beginning_of_day..Time.current
    when "yearly"
      Time.current.beginning_of_year..Time.current
    when "7_days"
      7.days.ago.beginning_of_day..Time.current
    when "30_days"
      30.days.ago.beginning_of_day..Time.current
    when "all_time"
      actual_data_range
    end
  end

  def group_by_resolution(answers)
    answers.group_by do |answer|
      case resolution
      when "five_minute"
        answer.created_at.beginning_of_hour + (answer.created_at.min / 5) * 5.minutes
      when "hour"
        answer.created_at.beginning_of_hour
      when "day"
        answer.created_at.beginning_of_day
      when "week"
        answer.created_at.beginning_of_week
      when "month"
        answer.created_at.beginning_of_month
      end
    end
  end

  def numeric_value(answer)
    case answer.answer_type
    when "number", "range"
      answer.number_value || 0
    when "bool"
      answer.bool_value ? 1 : 0
    when "string"
      0 # Strings don't have numeric value for aggregation
    else
      0 # Default fallback for unknown answer types
    end
  end

  def generate_time_buckets
    range = time_range
    buckets = []
    current_time = bucket_start_for_time(range.begin)

    while current_time <= range.end
      buckets << current_time
      current_time = next_bucket_start(current_time)
    end

    buckets
  end

  def bucket_start_for_time(time)
    case resolution
    when "five_minute"
      time.beginning_of_hour + (time.min / 5) * 5.minutes
    when "hour"
      time.beginning_of_hour
    when "day"
      time.beginning_of_day
    when "week"
      time.beginning_of_week
    when "month"
      time.beginning_of_month
    end
  end

  def next_bucket_start(current_bucket)
    case resolution
    when "five_minute"
      current_bucket + 5.minutes
    when "hour"
      current_bucket + 1.hour
    when "day"
      current_bucket + 1.day
    when "week"
      current_bucket + 1.week
    when "month"
      current_bucket + 1.month
    end
  end

  def actual_data_range
    case function
    when "answer"
      # For answer metrics, get range from associated questions' answers
      if questions.any?
        answers = Answer.joins(:response, :question)
                        .where(questions: { id: questions.pluck(:id) })
                        .where(responses: { user_id: user_id })

        if answers.any?
          earliest = answers.minimum(:created_at)
          latest = answers.maximum(:created_at)
          earliest..latest
        else
          # If no answers found, return a reasonable default range
          1.year.ago..Time.current
        end
      else
        # If no questions, return a reasonable default range
        1.year.ago..Time.current
      end
    else
      # For calculated metrics, get range from child metrics
      if child_metrics.any?
        child_ranges = child_metrics.map { |child| child.send(:actual_data_range) }
        earliest = child_ranges.map(&:begin).min
        latest = child_ranges.map(&:end).max
        earliest..latest
      else
        # If no child metrics, return a reasonable default range
        1.year.ago..Time.current
      end
    end
  end

  private

  def apply_fill_logic(raw_series)
    fill_method = fill || "none"

    case fill_method
    when "none"
      # Return only buckets with actual data
      raw_series.select { |bucket_time, value| value != nil }
    when "zero"
      # Fill missing values with 0.0
      raw_series.map { |bucket_time, value| [ bucket_time, value || 0.0 ] }
    when "previous"
      # Fill missing values with previous value
      previous_value = nil
      raw_series.map do |bucket_time, value|
        if value != nil
          previous_value = value
          [ bucket_time, value ]
        elsif previous_value != nil
          [ bucket_time, previous_value ]
        else
          nil
        end
      end.compact
    when "linear"
      # Fill missing values with linear interpolation
      apply_linear_interpolation(raw_series)
    else
      # Default to 'none' behavior
      raw_series.select { |bucket_time, value| value != nil }
    end
  end

  def apply_linear_interpolation(raw_series)
    result = []

    # Find all non-nil values with their indices
    non_nil_indices = []
    raw_series.each_with_index do |bucket_data, index|
      bucket_time, value = bucket_data
      if value != nil
        non_nil_indices << { index: index, time: bucket_time, value: value }
      end
    end

    return [] if non_nil_indices.empty?

    raw_series.each_with_index do |bucket_data, index|
      bucket_time, value = bucket_data

      if value != nil
        # Use actual value
        result << [ bucket_time, value ]
      else
        # Find surrounding non-nil values
        left_point = non_nil_indices.reverse.find { |point| point[:index] < index }
        right_point = non_nil_indices.find { |point| point[:index] > index }

        if left_point && right_point
          # Linear interpolation between two points
          x0, y0 = left_point[:index], left_point[:value]
          x1, y1 = right_point[:index], right_point[:value]

          # Calculate interpolated value
          interpolated_value = y0 + (y1 - y0) * (index - x0) / (x1 - x0)
          result << [ bucket_time, interpolated_value ]
        elsif left_point
          # Only left point exists, use its value (like 'previous')
          result << [ bucket_time, left_point[:value] ]
        elsif right_point
          # Only right point exists, use its value
          result << [ bucket_time, right_point[:value] ]
        else
          # No surrounding points, skip this bucket
          next
        end
      end
    end

    result
  end

  def store_child_metric_ids
    # child_metric_ids_temp is already set by the setter
  end

  def create_child_associations
    return unless @child_metric_ids_changed

    # Clear existing associations
    child_metric_metrics.destroy_all

    # Create new associations if any
    if @child_metric_ids_temp.present?
      @child_metric_ids_temp.each do |child_id|
        child_metric_metrics.create!(child_metric_id: child_id)
      end
    end
  end

  def invalidate_dependent_caches
    MetricDependencyService.invalidate_caches_for(self)
  end
end
