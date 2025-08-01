namespace :db do
  namespace :sync do
    desc "Export database to JSON for syncing between deployments"
    task export: :environment do
      require "json"
      require "fileutils"

      puts "🚀 Starting database export..."

      # Create export directory
      export_dir = Rails.root.join("tmp", "db_sync")
      FileUtils.mkdir_p(export_dir)

      timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
      export_file = export_dir.join("db_export_#{timestamp}.json")

      export_data = {}

      # Get all models that inherit from ApplicationRecord
      models = [
        User, Question, Form, Section, Response, Answer,
        Metric, Alert, Report, Dashboard, DashboardMetric,
        DashboardAlert, DashboardForm, DashboardQuestion, DashboardDashboard,
        AlertStatusCache, ReportAlert, ReportMetric,
        MetricQuestion
      ]

      models.each do |model|
        table_name = model.table_name
        puts "📊 Exporting #{table_name}..."

        records = model.all.map do |record|
          attributes = record.attributes
          # Convert any binary data to base64
          attributes.each do |key, value|
            if value.is_a?(String) && !value.valid_encoding?
              attributes[key] = Base64.encode64(value)
            end
          end
          attributes
        end

        export_data[table_name] = records
        puts "  ✅ #{records.count} records exported"
      end

      # Export join tables that don't have models
      puts "📊 Exporting questions_sections..."
      join_records = ActiveRecord::Base.connection.execute("SELECT * FROM questions_sections").map do |row|
        # Convert to hash with string keys
        row.is_a?(Hash) ? row : Hash[ActiveRecord::Base.connection.columns("questions_sections").map(&:name).zip(row)]
      end
      export_data["questions_sections"] = join_records
      puts "  ✅ #{join_records.count} records exported"

      # Save to file
      File.write(export_file, JSON.pretty_generate(export_data))

      puts
      puts "✅ Export completed successfully!"
      puts "📁 File: #{export_file}"
      puts "💾 Size: #{File.size(export_file)} bytes"
      puts
      puts "Summary:"
      export_data.each do |table_name, records|
        puts "  #{table_name}: #{records.count} records"
      end
    end

    desc "Import database from JSON export"
    task :import, [ :file ] => :environment do |t, args|
      require "json"

      export_file = args[:file]

      if export_file.nil?
        puts "❌ Please specify an export file:"
        puts "   rails db:sync:import[path/to/export.json]"
        exit 1
      end

      unless File.exist?(export_file)
        puts "❌ Export file not found: #{export_file}"
        exit 1
      end

      puts "🚀 Starting database import..."
      puts "📁 File: #{export_file}"

      export_data = JSON.parse(File.read(export_file))

      # Confirmation prompt
      print "⚠️  This will DELETE all existing data and replace it. Continue? (y/N): "
      response = STDIN.gets.chomp.downcase

      unless response == "y" || response == "yes"
        puts "❌ Import cancelled"
        exit 1
      end

      # Clear existing data (in reverse dependency order)
      puts "🗑️  Clearing existing data..."
      [
        AlertStatusCache, ReportAlert, ReportMetric, MetricQuestion,
        DashboardMetric, DashboardAlert, DashboardForm, DashboardQuestion, DashboardDashboard,
        Answer, Response, Alert, Report, Dashboard, Metric,
        Section, Question, Form, User
      ].each do |model|
        count = model.count
        model.delete_all
        puts "  🧹 Cleared #{count} records from #{model.table_name}"
      end

      # Import data in correct order (respecting foreign keys)
      import_order = [
        "users", "forms", "sections", "questions", "responses", "answers",
        "metrics", "alerts", "reports", "dashboards", "dashboard_metrics",
        "dashboard_alerts", "dashboard_forms", "dashboard_questions", "dashboard_dashboards",
        "alert_status_caches", "report_alerts", "report_metrics",
        "metric_questions", "questions_sections"
      ]

      import_order.each do |table_name|
        next unless export_data[table_name]

        records = export_data[table_name]
        puts "📥 Importing #{records.count} records to #{table_name}..."

        if table_name == "questions_sections"
          # Handle join table without model
          imported_count = 0
          records.each_with_index do |record_data, index|
            begin
              ActiveRecord::Base.connection.execute(
                "INSERT INTO questions_sections (question_id, section_id) VALUES (#{record_data['question_id']}, #{record_data['section_id']})"
              )
              imported_count += 1
            rescue => e
              puts "  ⚠️  Warning: Failed to import record #{index + 1}: #{e.message}"
            end
          end
        else
          # Handle regular model tables
          model_class = table_name.classify.constantize
          imported_count = 0

          records.each_with_index do |record_data, index|
            begin
              # Handle timestamps and other special fields
              %w[created_at updated_at].each do |field|
                if record_data[field]
                  record_data[field] = Time.parse(record_data[field])
                end
              end

              model_class.create!(record_data)
              imported_count += 1
            rescue => e
              puts "  ⚠️  Warning: Failed to import record #{index + 1}: #{e.message}"
            end
          end
        end

        puts "  ✅ Successfully imported #{imported_count}/#{records.count} records"
      end

      puts
      puts "✅ Database import completed successfully!"
      puts
      puts "📊 Final summary:"
      import_order.each do |table_name|
        next unless export_data[table_name]
        model_class = table_name.classify.constantize
        puts "  #{table_name}: #{model_class.count} records"
      end
    end

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
