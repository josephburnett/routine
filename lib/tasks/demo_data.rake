namespace :demo do
  desc "Create demo data to showcase report features"
  task create: :environment do
    puts "Creating demo data..."
    
    # Find the first user (assuming development has at least one user)
    user = User.first
    unless user
      puts "No users found. Please create a user first."
      exit 1
    end
    
    puts "Using user: #{user.email}"
    
    # Clean up existing demo data in correct order (respecting foreign keys)
    puts "Cleaning up existing demo data..."
    Report.where(namespace: 'demo').destroy_all
    Alert.where(namespace: 'demo').destroy_all
    Answer.joins(:question).where(questions: { namespace: 'demo' }).destroy_all
    Metric.where(namespace: 'demo').destroy_all
    Question.where(namespace: 'demo').destroy_all
    
    # Create questions for different scenarios
    puts "Creating questions..."
    
    pool_filter = Question.create!(
      name: "Pool Filter Cleaned",
      question_type: "bool",
      user: user,
      namespace: "demo"
    )
    
    water_temp = Question.create!(
      name: "Pool Water Temperature",
      question_type: "number",
      user: user,
      namespace: "demo"
    )
    
    meditation = Question.create!(
      name: "Daily Meditation",
      question_type: "bool",
      user: user,
      namespace: "demo"
    )
    
    stress_level = Question.create!(
      name: "Stress Level",
      question_type: "range",
      range_min: 1,
      range_max: 10,
      user: user,
      namespace: "demo"
    )
    
    exercise_minutes = Question.create!(
      name: "Exercise Minutes",
      question_type: "number",
      user: user,
      namespace: "demo"
    )
    
    # Additional questions for partial progress demonstrations
    sleep_hours = Question.create!(
      name: "Hours of Sleep",
      question_type: "number",
      user: user,
      namespace: "demo"
    )
    
    caffeine_intake = Question.create!(
      name: "Caffeine Intake (mg)",
      question_type: "number",
      user: user,
      namespace: "demo"
    )
    
    # Create answers with different patterns for demonstration
    puts "Creating sample answers..."
    
    base_time = 20.days.ago
    
    # Pool Filter - should show 67% progress (2 out of 3 days missed)
    (0..19).each do |day|
      Answer.create!(
        question: pool_filter,
        user: user,
        answer_type: "bool",
        bool_value: day < 17 ? true : false, # Last 3 days: true, false, false
        created_at: base_time + day.days
      )
    end
    
    # Water Temperature - should show 100% activated (all above 85°F)
    (0..19).each do |day|
      temp = day < 17 ? rand(75..84) : rand(86..90) # Last 3 days all above 85
      Answer.create!(
        question: water_temp,
        user: user,
        answer_type: "number",
        number_value: temp,
        created_at: base_time + day.days
      )
    end
    
    # Meditation - should show 20% progress (1 out of 5 days done)
    (0..19).each do |day|
      # Last 5 days: false, false, false, false, true (only last day done)
      done = day < 15 ? [true, false].sample : (day == 19 ? true : false)
      Answer.create!(
        question: meditation,
        user: user,
        answer_type: "bool",
        bool_value: done,
        created_at: base_time + day.days
      )
    end
    
    # Stress Level - should show 75% progress (3 out of 4 days high stress)
    (0..19).each do |day|
      # Last 4 days: 8, 7, 8, 4 (3 out of 4 above 6)
      if day < 16
        level = rand(3..6)
      else
        levels = [8, 7, 8, 4]
        level = levels[day - 16]
      end
      Answer.create!(
        question: stress_level,
        user: user,
        answer_type: "range",
        number_value: level,
        created_at: base_time + day.days
      )
    end
    
    # Exercise Minutes - should show 0% progress (recent drop below 30)
    (0..19).each do |day|
      # Last 7 days: all below 30 minutes after being above
      minutes = day < 13 ? rand(30..60) : rand(10..25)
      Answer.create!(
        question: exercise_minutes,
        user: user,
        answer_type: "number",
        number_value: minutes,
        created_at: base_time + day.days
      )
    end
    
    # Sleep Hours - should show 10% progress (1/10 consecutive days below 6 hours)
    (0..19).each do |day|
      # Last 10 days: only the most recent day below 6 hours, rest above
      # Pattern: [7, 8, 7.5, 8, 7, 8.5, 7, 8, 7.5, 5.5] - only last day triggers
      if day < 10
        hours = rand(7.0..8.5)  # Normal sleep
      elsif day < 19
        hours = [7.0, 8.0, 7.5, 8.0, 7.0, 8.5, 7.0, 8.0, 7.5][day - 10]  # Good sleep
      else
        hours = 5.5  # Last day only - below threshold
      end
      Answer.create!(
        question: sleep_hours,
        user: user,
        answer_type: "number",
        number_value: hours,
        created_at: base_time + day.days
      )
    end
    
    # Caffeine Intake - should show 75% progress (3/4 consecutive days above 400mg)
    (0..19).each do |day|
      # Last 4 days: [350, 450, 420, 480] - 3 out of 4 above 400mg threshold
      if day < 16
        mg = rand(100..350)  # Normal caffeine
      else
        caffeine_values = [350, 450, 420, 480]  # Only first value is below 400
        mg = caffeine_values[day - 16]
      end
      Answer.create!(
        question: caffeine_intake,
        user: user,
        answer_type: "number",
        number_value: mg,
        created_at: base_time + day.days
      )
    end
    
    # Create metrics
    puts "Creating metrics..."
    
    pool_metric = Metric.create!(
      name: "Pool Filter Maintenance",
      function: "answer",
      resolution: "day",
      width: "30_days",
      namespace: "demo",
      user: user
    )
    pool_metric.questions << pool_filter
    
    temp_metric = Metric.create!(
      name: "Pool Temperature",
      function: "answer",
      resolution: "day",
      width: "30_days",
      namespace: "demo",
      user: user
    )
    temp_metric.questions << water_temp
    
    meditation_metric = Metric.create!(
      name: "Meditation Consistency",
      function: "answer",
      resolution: "day",
      width: "30_days",
      namespace: "demo",
      user: user
    )
    meditation_metric.questions << meditation
    
    stress_metric = Metric.create!(
      name: "Stress Level",
      function: "answer",
      resolution: "day",
      width: "30_days",
      namespace: "demo",
      user: user
    )
    stress_metric.questions << stress_level
    
    exercise_metric = Metric.create!(
      name: "Exercise Minutes",
      function: "answer",
      resolution: "day",
      width: "30_days",
      namespace: "demo",
      user: user
    )
    exercise_metric.questions << exercise_minutes
    
    sleep_metric = Metric.create!(
      name: "Sleep Duration",
      function: "answer",
      resolution: "day",
      width: "30_days",
      namespace: "demo",
      user: user
    )
    sleep_metric.questions << sleep_hours
    
    caffeine_metric = Metric.create!(
      name: "Caffeine Intake",
      function: "answer",
      resolution: "day",
      width: "30_days",
      namespace: "demo",
      user: user
    )
    caffeine_metric.questions << caffeine_intake
    
    # Create alerts in different states
    puts "Creating alerts..."
    
    # Alert 1: 67% progress (2/3 consecutive days without cleaning)
    alert1 = Alert.create!(
      name: "Pool Filter Overdue",
      metric: pool_metric,
      threshold: 0.5,
      direction: "below",
      delay: 3,
      namespace: "demo",
      user: user
    )
    
    # Alert 2: 100% activated (3/3 days above 85°F)
    alert2 = Alert.create!(
      name: "Pool Too Hot",
      metric: temp_metric,
      threshold: 85.0,
      direction: "above",
      delay: 3,
      namespace: "demo",
      user: user
    )
    
    # Alert 3: 20% progress (1/5 days with meditation)
    alert3 = Alert.create!(
      name: "Missing Meditation",
      metric: meditation_metric,
      threshold: 0.5,
      direction: "below",
      delay: 5,
      namespace: "demo",
      user: user
    )
    
    # Alert 4: 75% progress (3/4 days high stress)
    alert4 = Alert.create!(
      name: "High Stress Level",
      metric: stress_metric,
      threshold: 6.0,
      direction: "above",
      delay: 4,
      namespace: "demo",
      user: user
    )
    
    # Alert 5: 0% progress (exercise dropped but not consecutive enough)
    alert5 = Alert.create!(
      name: "Low Exercise",
      metric: exercise_metric,
      threshold: 30.0,
      direction: "below",
      delay: 7,
      namespace: "demo",
      user: user
    )
    
    # Alert 6: Single point delay (always 100% if condition met)
    alert6 = Alert.create!(
      name: "Critical Stress",
      metric: stress_metric,
      threshold: 9.0,
      direction: "above",
      delay: 1,
      namespace: "demo",
      user: user
    )
    
    # Alert 7: 10% progress (1/10 consecutive days below 6 hours sleep) - GREEN
    alert7 = Alert.create!(
      name: "Sleep Deprivation",
      metric: sleep_metric,
      threshold: 6.0,
      direction: "below",
      delay: 10,
      namespace: "demo",
      user: user
    )
    
    # Alert 8: 75% progress (3/4 consecutive days above 400mg caffeine) - YELLOW
    alert8 = Alert.create!(
      name: "High Caffeine Intake",
      metric: caffeine_metric,
      threshold: 400.0,
      direction: "above",
      delay: 4,
      namespace: "demo",
      user: user
    )
    
    # Create the Demo report
    puts "Creating Demo report..."
    
    report = Report.create!(
      name: "Demo Report",
      interval_type: "weekly",
      time_of_day: Time.parse("09:00"),
      interval_config: { "days" => ["monday", "wednesday", "friday"] },
      namespace: "demo",
      user: user
    )
    
    # Add alerts to report
    [alert1, alert2, alert3, alert4, alert5, alert6, alert7, alert8].each do |alert|
      ReportAlert.create!(report: report, alert: alert)
    end
    
    # Add metrics to report  
    [pool_metric, temp_metric, meditation_metric, stress_metric, exercise_metric, sleep_metric, caffeine_metric].each do |metric|
      ReportMetric.create!(report: report, metric: metric)
    end
    
    puts ""
    puts "Demo data created successfully!"
    puts ""
    puts "You can now:"
    puts "1. Visit http://localhost:3000/namespaces/demo to see all demo entities"
    puts "2. View the Demo Report at reports (filter to 'demo' namespace)"
    puts "3. Check individual alerts to see their progress"
    puts ""
    puts "Alert progress levels created:"
    puts "• Pool Filter Overdue: ~67% (2/3 consecutive violations)"
    puts "• Pool Too Hot: 100% (ACTIVATED - 3/3 consecutive violations)"
    puts "• Missing Meditation: ~20% (1/5 consecutive violations)"
    puts "• High Stress Level: ~75% (3/4 consecutive violations)"
    puts "• Low Exercise: 0% (recent violations but not consecutive)"
    puts "• Critical Stress: 0% (single point delay, not currently violated)"
    puts "• Sleep Deprivation: 10% (1/10 consecutive violations) - GREEN bar"
    puts "• High Caffeine Intake: 75% (3/4 consecutive violations) - YELLOW bar"
    puts ""
    puts "The report view will show progress bars in different colors:"
    puts "• Green: 0-74% progress"
    puts "• Yellow: 75-99% progress"  
    puts "• Red: 100% activated"
  end
  
  desc "Remove demo data"
  task clean: :environment do
    puts "Removing demo data..."
    
    Alert.where(namespace: 'demo').destroy_all
    Metric.where(namespace: 'demo').destroy_all
    Question.where(namespace: 'demo').destroy_all
    Report.where(namespace: 'demo').destroy_all
    Answer.joins(:question).where(questions: { namespace: 'demo' }).destroy_all
    
    puts "Demo data removed."
  end
end