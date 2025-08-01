namespace :db do
  namespace :sync do
    # NOTE: Export and import tasks removed - now using SQLite native tools
    # via _export_database.sh and _import_database.sh scripts for better reliability

    desc "Show database sync status and record counts"
    task status: :environment do
      puts "📊 Database Sync Status"
      puts "=" * 50
      puts "Environment: #{Rails.env}"
      puts "Host: #{ENV.fetch('APPLICATION_HOST', 'unknown')}"
      puts "Database: #{ActiveRecord::Base.connection_db_config.database}"
      puts "Time: #{Time.current}"
      puts

      models = [
        User, Question, Form, Section, Response, Answer,
        Metric, Alert, Report, Dashboard, DashboardMetric,
        DashboardAlert, DashboardForm, DashboardQuestion, DashboardDashboard,
        AlertStatusCache, ReportAlert, ReportMetric,
        MetricQuestion
      ]

      puts "📋 Record Counts:"
      total_records = 0

      models.each do |model|
        count = model.count
        total_records += count
        puts "  #{model.table_name.ljust(20)}: #{count.to_s.rjust(6)} records"
      end

      puts "  #{'=' * 20}   #{'=' * 6}"
      puts "  #{'Total'.ljust(20)}: #{total_records.to_s.rjust(6)} records"

      # Show recent activity
      puts
      puts "📅 Recent Activity:"

      if User.any?
        recent_answers = Answer.order(created_at: :desc).limit(5)
        if recent_answers.any?
          puts "  Last 5 answers:"
          recent_answers.each do |answer|
            puts "    #{answer.created_at.strftime('%Y-%m-%d %H:%M')} - #{answer.question.name}"
          end
        else
          puts "  No answers found"
        end
      else
        puts "  No data available"
      end
    end
  end
end
