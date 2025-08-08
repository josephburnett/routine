require "svggraph"

module ChartHelper
  def render_metric_chart(series_data, metric)
    return content_tag(:p, "No data available for this metric configuration.") if series_data.empty?

    if metric.wrap.present? && metric.wrap != "none"
      render_wrapped_chart(series_data, metric)
    else
      render_regular_chart(series_data, metric)
    end
  end

  private

  def render_regular_chart(series_data, metric)
    # Use SVG::Graph::Plot for scatter-like plots or Line for connected points
    # Let's use Line chart but without connecting lines for scatter effect
    data_points = []
    labels = []

    series_data.each_with_index do |(time, value), index|
      data_points << value.round(2)
      labels << format_time_label(time, metric.resolution)
    end

    graph = SVG::Graph::Line.new({
      height: 400,
      width: 800,
      fields: labels,
      graph_title: chart_title(metric),
      show_graph_title: true,
      show_x_guidelines: true,
      show_y_guidelines: true,
      show_data_values: false,
      min_scale_value: 0,
      scale_integers: false,
      show_x_labels: true,
      stagger_x_labels: labels.length > 10,
      font_size: 12,
      title_font_size: 16,
      key_font_size: 10,
      x_title: time_axis_label(metric),
      y_title: "Value",
      area_fill: false,
      show_lines: false  # This should make it scatter-like
    })

    graph.add_data({
      data: data_points,
      title: "#{metric.type.capitalize} Value"
    })

    graph.burn.html_safe
  end

  def render_wrapped_chart(series_data, metric)
    case metric.wrap
    when "day"
      render_day_wrapped_chart(series_data, metric)
    when "hour"
      render_hour_wrapped_chart(series_data, metric)
    when "weekly"
      render_weekly_wrapped_chart(series_data, metric)
    else
      render_regular_chart(series_data, metric)
    end
  end

  def render_day_wrapped_chart(series_data, metric)
    # For day wrap, convert times to minutes since midnight
    data_points = []
    x_values = []

    series_data.each do |time, value|
      minutes_since_midnight = time.hour * 60 + time.min
      x_values << minutes_since_midnight
      data_points << [ minutes_since_midnight, value.round(2) ]
    end

    # Create custom SVG for day wrap with proper time axis
    create_scatter_svg(data_points, {
      title: "#{chart_title(metric)} (Wrapped by Day)",
      x_title: "Time of Day",
      y_title: "Value",
      x_min: 0,
      x_max: 1440,
      x_formatter: method(:format_minutes_to_time)
    })
  end

  def render_hour_wrapped_chart(series_data, metric)
    # For hour wrap, use minutes (0-59)
    data_points = []

    series_data.each do |time, value|
      minute = time.min
      data_points << [ minute, value.round(2) ]
    end

    create_scatter_svg(data_points, {
      title: "#{chart_title(metric)} (Wrapped by Hour)",
      x_title: "Minutes (0-59)",
      y_title: "Value",
      x_min: 0,
      x_max: 59
    })
  end

  def render_weekly_wrapped_chart(series_data, metric)
    # For weekly wrap, use day of week + hour
    data_points = []
    labels = []

    series_data.each do |time, value|
      day_hour = time.wday * 24 + time.hour
      data_points << [ day_hour, value.round(2) ]
      labels << "#{Date::DAYNAMES[time.wday][0..2]} #{time.strftime('%H:%M')}"
    end

    create_scatter_svg(data_points, {
      title: "#{chart_title(metric)} (Wrapped by Week)",
      x_title: "Day of Week",
      y_title: "Value",
      x_min: 0,
      x_max: 7 * 24,
      labels: labels
    })
  end

  def create_scatter_svg(data_points, options = {})
    title = options[:title] || "Chart"
    x_title = options[:x_title] || "X"
    y_title = options[:y_title] || "Y"
    width = options[:width] || 800
    height = options[:height] || 400

    return content_tag(:p, "No data points available") if data_points.empty?

    # Calculate bounds
    x_values = data_points.map(&:first)
    y_values = data_points.map(&:last)

    x_min = options[:x_min] || x_values.min
    x_max = options[:x_max] || x_values.max
    y_min = [ 0, y_values.min ].min
    y_max = y_values.max

    # Add padding
    x_range = x_max - x_min
    y_range = y_max - y_min
    x_padding = x_range * 0.05
    y_padding = y_range * 0.1

    x_min -= x_padding
    x_max += x_padding
    y_max += y_padding

    # SVG dimensions
    margin = { top: 60, right: 40, bottom: 80, left: 80 }
    chart_width = width - margin[:left] - margin[:right]
    chart_height = height - margin[:top] - margin[:bottom]

    svg_content = <<~SVG
      <svg width="#{width}" height="#{height}" xmlns="http://www.w3.org/2000/svg">
        <style>
          .chart-title { font-family: Arial, sans-serif; font-size: 16px; font-weight: bold; text-anchor: middle; }
          .axis-title { font-family: Arial, sans-serif; font-size: 12px; text-anchor: middle; }
          .axis-label { font-family: Arial, sans-serif; font-size: 10px; text-anchor: middle; }
          .grid-line { stroke: #e0e0e0; stroke-width: 1; }
          .axis-line { stroke: #000; stroke-width: 2; }
          .data-point { fill: rgba(75, 192, 192, 0.6); stroke: rgb(75, 192, 192); stroke-width: 2; }
        </style>
      #{'  '}
        <!-- Title -->
        <text x="#{width / 2}" y="30" class="chart-title">#{title}</text>
      #{'  '}
        <!-- Grid lines -->
        #{generate_grid_lines(x_min, x_max, y_min, y_max, margin, chart_width, chart_height)}
      #{'  '}
        <!-- Axes -->
        <line x1="#{margin[:left]}" y1="#{margin[:top]}" x2="#{margin[:left]}" y2="#{margin[:top] + chart_height}" class="axis-line"/>
        <line x1="#{margin[:left]}" y1="#{margin[:top] + chart_height}" x2="#{margin[:left] + chart_width}" y2="#{margin[:top] + chart_height}" class="axis-line"/>
      #{'  '}
        <!-- Data points -->
        #{generate_data_points(data_points, x_min, x_max, y_min, y_max, margin, chart_width, chart_height)}
      #{'  '}
        <!-- Axis labels -->
        #{generate_axis_labels(x_min, x_max, y_min, y_max, margin, chart_width, chart_height, options)}
      #{'  '}
        <!-- Axis titles -->
        <text x="#{width / 2}" y="#{height - 20}" class="axis-title">#{x_title}</text>
        <text x="20" y="#{height / 2}" class="axis-title" transform="rotate(-90, 20, #{height / 2})">#{y_title}</text>
      </svg>
    SVG

    svg_content.html_safe
  end

  def generate_grid_lines(x_min, x_max, y_min, y_max, margin, chart_width, chart_height)
    lines = []

    # Vertical grid lines (5-7 lines)
    x_step = (x_max - x_min) / 6.0
    (0..6).each do |i|
      x_pos = margin[:left] + (i / 6.0) * chart_width
      lines << "<line x1='#{x_pos}' y1='#{margin[:top]}' x2='#{x_pos}' y2='#{margin[:top] + chart_height}' class='grid-line'/>"
    end

    # Horizontal grid lines (5-7 lines)
    y_step = (y_max - y_min) / 6.0
    (0..6).each do |i|
      y_pos = margin[:top] + chart_height - (i / 6.0) * chart_height
      lines << "<line x1='#{margin[:left]}' y1='#{y_pos}' x2='#{margin[:left] + chart_width}' y2='#{y_pos}' class='grid-line'/>"
    end

    lines.join("\n")
  end

  def generate_data_points(data_points, x_min, x_max, y_min, y_max, margin, chart_width, chart_height)
    points = []

    data_points.each do |x, y|
      x_pos = margin[:left] + ((x - x_min) / (x_max - x_min)) * chart_width
      y_pos = margin[:top] + chart_height - ((y - y_min) / (y_max - y_min)) * chart_height

      points << "<circle cx='#{x_pos}' cy='#{y_pos}' r='4' class='data-point'/>"
    end

    points.join("\n")
  end

  def generate_axis_labels(x_min, x_max, y_min, y_max, margin, chart_width, chart_height, options)
    labels = []

    # X-axis labels
    (0..6).each do |i|
      x_value = x_min + (i / 6.0) * (x_max - x_min)
      x_pos = margin[:left] + (i / 6.0) * chart_width
      y_pos = margin[:top] + chart_height + 15

      label_text = if options[:x_formatter]
                    options[:x_formatter].call(x_value)
      else
                    x_value.round(1).to_s
      end

      labels << "<text x='#{x_pos}' y='#{y_pos}' class='axis-label'>#{label_text}</text>"
    end

    # Y-axis labels
    (0..6).each do |i|
      y_value = y_min + (i / 6.0) * (y_max - y_min)
      x_pos = margin[:left] - 10
      y_pos = margin[:top] + chart_height - (i / 6.0) * chart_height + 4

      labels << "<text x='#{x_pos}' y='#{y_pos}' class='axis-label' text-anchor='end'>#{y_value.round(1)}</text>"
    end

    labels.join("\n")
  end

  def format_time_label(time, resolution)
    case resolution
    when "five_minute", "hour"
      time.strftime("%m/%d %H:%M")
    when "day"
      time.strftime("%m/%d")
    when "week"
      time.strftime("Wk %m/%d")
    when "month"
      time.strftime("%b %Y")
    else
      time.strftime("%m/%d")
    end
  end

  def format_x_label(value)
    value.to_s
  end

  def format_minutes_to_time(minutes)
    hours = (minutes / 60).to_i
    mins = (minutes % 60).to_i
    "%02d:%02d" % [ hours, mins ]
  end

  def chart_title(metric)
    "Metric: #{metric.function.capitalize} Function"
  end

  def time_axis_label(metric)
    case metric.resolution
    when "five_minute"
      "Time (5-min intervals)"
    when "hour"
      "Time (hourly)"
    when "day"
      "Date"
    when "week"
      "Week"
    when "month"
      "Month"
    else
      "Time"
    end
  end
end
