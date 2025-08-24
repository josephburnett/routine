# Comprehensive Guide: How Metrics Are Calculated

Based on analysis of `/home/joseph/routine/app/models/metric.rb` and related code, here's an in-depth explanation of how metrics work and how each field affects the series data:

## Core Metric Fields

### 1. **function** (Required)
Determines how data is aggregated from source data. The function applies at TWO levels:

1. **Within time buckets**: When multiple answers to the same question fall in the same time bucket
2. **Across sources**: When combining different questions or child metrics

Valid options:
- **`"answer"`** - Legacy: now behaves like `sum` for backward compatibility
- **`"sum"`** - Adds values together (both within buckets and across sources)
- **`"average"`** - Averages values (both within buckets and across sources)
- **`"difference"`** - Subtracts: first value minus sum of remaining values
- **`"count"`** - Legacy: now behaves like `sum` for backward compatibility

**Example**: Exercise Minutes with `function: "sum"` and `resolution: "week"`:
- Daily answers of 30, 20, 15 minutes → Weekly total = 65 minutes (summed, not averaged)

### 2. **resolution** (Required)
Defines the time granularity for data bucketing:
- **`"five_minute"`** - Groups data into 5-minute intervals
- **`"hour"`** - Groups data into hourly intervals
- **`"day"`** - Groups data into daily intervals (midnight to midnight)
- **`"week"`** - Groups data into weekly intervals (beginning of week)
- **`"month"`** - Groups data into monthly intervals (beginning of month)

### 3. **width** (Required) 
Defines the time range window for data collection:
- **`"daily"`** - Today from beginning of day to now
- **`"weekly"`** - This week (Saturday to now)
- **`"monthly"`** - This month from beginning to now
- **`"7_days"`** - Last 7 days from midnight 7 days ago
- **`"30_days"`** - Last 30 days from midnight 30 days ago
- **`"90_days"`** - Last 90 days from midnight 90 days ago
- **`"yearly"`** - This year from beginning to now
- **`"all_time"`** - Full range based on actual data timestamps

## Optional Enhancement Fields

### 4. **scale** (Optional, default: 1.0)
Multiplies all values by this factor after aggregation. Applied to answer data before function operations.

**Example**: If `scale = 2.0` and raw answer value is `5`, becomes `10` in the series.

### 5. **fill** (Optional, default: "none")
Handles missing data points in time buckets:
- **`"none"`** - Only returns time buckets that have actual data
- **`"zero"`** - Fills empty buckets with `0.0`
- **`"previous"`** - Forward-fills using the last known value
- **`"linear"`** - Interpolates missing values between known points

### 6. **wrap** (Optional, default: "none")
Maps timestamps to cyclical patterns for overlay analysis:
- **`"none"`** - No wrapping (normal chronological time)
- **`"hour"`** - Maps all data to positions within a single reference hour (0-59 minutes)
- **`"day"`** - Maps all data to positions within a single reference day (0-23:59:59)  
- **`"weekly"`** - Maps all data to positions within a single reference week (Monday-Sunday)

**Use case**: Compare daily patterns across multiple days, or weekly patterns across multiple weeks.

### 7. **first_metric_id** (Optional)
Only used with `function = "difference"`. Specifies which child metric to use as the "primary" value that others are subtracted from. If not set, uses the first child metric.

## Data Sources

Metrics can aggregate data from two types of sources:

### Question Sources
- Connected via `metric_questions` join table
- Raw answer data is bucketed according to metric's `resolution` and `width`
- Answer types converted to numeric: `number/range` → value, `bool` → 1/0, `string` → 0
- Applied in sequence: scale → bucketing → function → fill

### Child Metric Sources  
- Connected via `metric_metrics` join table (parent-child relationships)
- Child metrics are calculated first, then rebucketed to match parent's parameters
- Prevents circular references through validation

## Calculation Process

The metric calculation follows this flow (`calculate_series_uncached:73-99`):

1. **Collect Sources** (`collect_all_source_series:168-184`)
   - Gather series from all connected questions 
   - Gather series from all child metrics
   - Questions are already in target parameters
   - Child metrics need rebucketing

2. **Rebucket to Target Parameters** (`rebucket_sources_to_target_parameters:186-202`)
   - Question sources: no rebucketing needed (already match target)
   - Child metric sources: rebucket from their resolution/width to this metric's resolution/width
   - Handles resolution conversions (hourly→daily, daily→weekly, etc.)

3. **Apply Function Across Sources** (`apply_function_across_sources:204-246`)
   - For each time bucket, collect values from all sources
   - Apply the specified function (sum/average/difference)
   - Handle missing data (sources without data for specific buckets)

4. **Apply Fill Logic** (`apply_fill_logic:683-713`) 
   - Fill missing time buckets according to `fill` setting
   - Linear interpolation calculates intermediate values between known points

## Advanced Features

### Caching System
- Results cached in `metric_series_cache` table with freshness tracking
- Cache invalidation via `MetricDependencyService` when dependencies change
- Cache automatically updated when source data (answers/child metrics) changes

### Wrap Functionality
When `wrap` is enabled (`wrap_timestamp:353-372`):
- Timestamps mapped to cyclical positions within reference period
- Multiple data points at same wrapped position are averaged
- Useful for pattern analysis (e.g., "What's my mood at 3 PM across all days?")

### Rebucketing Logic  
Child metrics can have different `resolution`/`width` than parent:
- **Finer→Coarser**: Hourly child → Daily parent (values summed)
- **Coarser→Finer**: Daily child → Hourly parent (value distributed)  
- **Time Range Conversion**: 7-day child → Monthly parent (overlap detection)

## Example Scenarios

**Daily Step Count Metric:**
- `function: "sum"`, `resolution: "day"`, `width: "monthly"`  
- If multiple step entries per day: sums them within each day
- Then shows each day's total for the current month
- `fill: "zero"` ensures missing days show as 0 steps

**Weekly Exercise Minutes (Production Example):**
- `function: "sum"`, `resolution: "week"`, `width: "90_days"`
- Daily answers of 30, 20, 15, 0, 45, 10, 25 → Weekly total = 145 minutes
- Each week sums all daily exercise entries (not averages)

**Weekly Weight Average:**
- `function: "average"`, `resolution: "week"`, `width: "yearly"`
- Multiple weight measurements per week: averaged within each week
- Then shows each week's average for the current year  
- `fill: "previous"` carries forward last known weight

**Mood Patterns by Hour:**
- `function: "average"`, `resolution: "hour"`, `wrap: "day"`
- Multiple mood entries at same hour: averaged within that hour
- Shows average mood by hour of day across all historical data
- All timestamps mapped to 24-hour reference period

This system provides flexible time-series aggregation with powerful composition capabilities for building complex derived metrics from simpler data sources.