class MetricSeriesCache < ApplicationRecord
  belongs_to :metric

  scope :fresh, -> { where("calculated_at > ?", 1.hour.ago) }

  def fresh?
    return false unless calculated_at && calculated_at > 1.hour.ago && calculated_at > metric.updated_at

    # Check if cache is newer than any source data that should affect this metric
    latest_source_data_time = metric.latest_source_data_timestamp
    return false if latest_source_data_time && calculated_at < latest_source_data_time

    true
  end

  def self.update_for_metric(metric)
    series_data = metric.calculate_series_uncached
    # Convert Time objects to ISO strings for JSON storage
    serialized_data = series_data.map do |time, value|
      [ time.iso8601, value ]
    end
    cache_record = find_or_initialize_by(metric: metric)
    cache_record.update!(
      series_data: serialized_data,
      calculated_at: Time.current
    )
    cache_record
  end

  def series_data
    # Convert ISO strings back to Time objects when retrieving
    raw_data = super
    return [] unless raw_data

    raw_data.map do |time_str, value|
      # Ensure value is numeric (handle string values from JSON)
      numeric_value = case value
      when String
        begin
          Float(value)
        rescue ArgumentError
          0.0  # Default to 0 for invalid numeric strings
        end
      when Numeric
        value
      else
        0.0  # Default to 0 for other types
      end
      [ Time.parse(time_str), numeric_value ]
    end
  end
end
