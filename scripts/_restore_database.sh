#!/bin/bash

#
# Restore Database to Laptop Script
#
# This script imports the database export from your Pi to your local laptop deployment.
# Run this on your laptop after copying the backup files from your Pi.
#
# Usage: ./scripts/restore_to_laptop.sh [path_to_export.json]
#

set -e

# Configuration
BACKUP_DIR="./tmp/pi_backup"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

echo "💻 Restoring database to laptop..."
echo "Timestamp: $TIMESTAMP"
echo

# Find export file
if [ -n "$1" ]; then
    EXPORT_FILE="$1"
elif [ -f "$BACKUP_DIR/db_export_"*.json ]; then
    EXPORT_FILE=$(ls -t "$BACKUP_DIR"/db_export_*.json | head -1)
else
    echo "❌ No export file found!"
    echo "Usage: $0 [path_to_export.json]"
    echo "Or place export file in $BACKUP_DIR/"
    exit 1
fi

if [ ! -f "$EXPORT_FILE" ]; then
    echo "❌ Export file not found: $EXPORT_FILE"
    exit 1
fi

echo "📁 Using export file: $EXPORT_FILE"

# Check if local deployment is running
echo "🔍 Checking local deployment status..."
if ! kamal app logs -d local &>/dev/null; then
    echo "⚠️  Local deployment not running. Starting deployment..."
    kamal deploy -d local
    echo "✅ Local deployment started"
else
    echo "✅ Local deployment is running"
fi

# Create import script
mkdir -p ./tmp
cat << 'EOF' > ./tmp/import_script.rb
# Import database from Pi export
require 'json'

export_file = ARGV[0]
unless File.exist?(export_file)
  puts "Export file not found: #{export_file}"
  exit 1
end

puts "Loading export data from #{export_file}..."
export_data = JSON.parse(File.read(export_file))

puts "Starting database import..."

# Clear existing data (be careful!)
puts "⚠️  Clearing existing data..."
[
  AlertStatusCache, ReportAlert, ReportMetric, MetricQuestion, SectionQuestion,
  DashboardItem, Answer, Response, Alert, Report, Dashboard, Metric, 
  Section, Question, Form, User
].each do |model|
  count = model.count
  model.delete_all
  puts "  Cleared #{count} records from #{model.table_name}"
end

# Import data in correct order (respecting foreign keys)
import_order = [
  'users', 'forms', 'sections', 'questions', 'responses', 'answers',
  'metrics', 'alerts', 'reports', 'dashboards', 'dashboard_items',
  'alert_status_caches', 'report_alerts', 'report_metrics',
  'metric_questions', 'section_questions'
]

import_order.each do |table_name|
  next unless export_data[table_name]
  
  records = export_data[table_name]
  puts "Importing #{records.count} records to #{table_name}..."
  
  model_class = table_name.classify.constantize
  
  records.each_with_index do |record_data, index|
    begin
      # Handle timestamps and other special fields
      %w[created_at updated_at].each do |field|
        if record_data[field]
          record_data[field] = Time.parse(record_data[field])
        end
      end
      
      model_class.create!(record_data)
    rescue => e
      puts "  Warning: Failed to import record #{index + 1}: #{e.message}"
    end
  end
  
  puts "  ✅ Imported #{records.count} records"
end

puts "✅ Database import completed successfully!"
puts
puts "Summary:"
export_data.each do |table_name, records|
  puts "  #{table_name}: #{records.count} records"
end
EOF

# Copy import script to local container and execute
echo "🚀 Executing import script on local container..."
kamal app exec -d local --reuse "mkdir -p /rails/tmp"
kamal app exec -d local --reuse "cat > /rails/tmp/import_script.rb" < ./tmp/import_script.rb
kamal app exec -d local --reuse "cat > /rails/tmp/export_data.json" < "$EXPORT_FILE"
kamal app exec -d local --reuse "bin/rails runner /rails/tmp/import_script.rb /rails/tmp/export_data.json"

echo
echo "✅ Database restored to laptop successfully!"
echo
echo "📋 Next steps:"
echo "1. Open your local app: http://localhost:8080"
echo "2. Verify your data is correctly imported"
echo "3. When you return home, use './scripts/sync_back_to_pi.sh' to sync changes back"
echo

# Clean up
rm -f ./tmp/import_script.rb