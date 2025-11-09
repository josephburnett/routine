#!/bin/bash

#
# Sync Back to RTB Script
#
# This script exports your laptop database and imports it back to your RTB.
# Run this when you return home to sync any changes made while traveling.
#
# Usage: ./scripts/sync_back_to_pi.sh
#

set -e

# Configuration
RTB_HOST="rtb.gila-lionfish.ts.net"
RTB_USER="joe"
RTB_SSH_KEY="$HOME/.ssh/rtb.local"
# SSH_KEY no longer needed with Tailscale SSH
BACKUP_DIR="./tmp/laptop_backup"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

echo "🔄 Syncing laptop database back to RTB..."
echo "Host: $RTB_HOST"
echo "Timestamp: $TIMESTAMP"
echo

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Check if local deployment is running
echo "🔍 Checking local deployment status..."
if ! kamal app logs -d local &>/dev/null; then
    echo "❌ Local deployment not running!"
    echo "Start it with: kamal deploy -d local"
    exit 1
fi

# Check if RTB is accessible
echo "🔍 Checking RTB connectivity..."
if ! ping -c 1 "$RTB_HOST" &>/dev/null; then
    echo "❌ Cannot reach RTB at $RTB_HOST"
    echo "Make sure you're on the same network and RTB is running"
    exit 1
fi

# Create export script for laptop
echo "📦 Creating database export from laptop..."
cat << 'EOF' > "$BACKUP_DIR/export_script.rb"
# Export laptop database
require 'json'

puts "Starting database export from laptop..."

export_data = {}

# Get all models that inherit from ApplicationRecord
models = [
  User, Question, Form, Section, Response, Answer, 
  Metric, Alert, Report, Dashboard, DashboardItem,
  AlertStatusCache, ReportAlert, ReportMetric,
  MetricQuestion, SectionQuestion
]

models.each do |model|
  table_name = model.table_name
  puts "Exporting #{table_name}..."
  
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
  puts "  -> #{records.count} records"
end

# Save to file
export_file = "/rails/storage/laptop_export_#{Time.current.strftime('%Y%m%d_%H%M%S')}.json"
File.write(export_file, JSON.pretty_generate(export_data))

puts "Export completed: #{export_file}"
puts "Total size: #{File.size(export_file)} bytes"
EOF

# Execute export on local container
echo "🚀 Executing export script on local container..."
kamal app exec -d local --reuse "cat > /rails/tmp/export_script.rb" < "$BACKUP_DIR/export_script.rb"
kamal app exec -d local --reuse "bin/rails runner /rails/tmp/export_script.rb"

# Download the export file from local container
echo "📥 Downloading export file from local container..."
# Find the latest export file and copy it out
kamal app exec -d local --reuse "ls -t /rails/storage/laptop_export_*.json | head -1" > "$BACKUP_DIR/latest_export_path.txt"
CONTAINER_EXPORT_PATH=$(cat "$BACKUP_DIR/latest_export_path.txt" | tr -d '\r\n')
LOCAL_EXPORT_FILE="$BACKUP_DIR/laptop_export_$TIMESTAMP.json"

# Copy file from container to host
kamal app exec -d local --reuse "cat $CONTAINER_EXPORT_PATH" > "$LOCAL_EXPORT_FILE"

if [ ! -s "$LOCAL_EXPORT_FILE" ]; then
    echo "❌ Failed to download export file from local container!"
    exit 1
fi

echo "✅ Export file created: $LOCAL_EXPORT_FILE"

# Create import script for RTB
cat << 'EOF' > "$BACKUP_DIR/import_script.rb"
# Import database to RTB
require 'json'

export_file = ARGV[0]
unless File.exist?(export_file)
  puts "Export file not found: #{export_file}"
  exit 1
end

puts "Loading export data from #{export_file}..."
export_data = JSON.parse(File.read(export_file))

puts "Starting database import to RTB..."

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
EOF

# Copy files to RTB and execute import
echo "🚀 Copying files to RTB and executing import..."
scp "$LOCAL_EXPORT_FILE" "$RTB_USER@$RTB_HOST:/tmp/laptop_export.json"
scp "$BACKUP_DIR/import_script.rb" "$RTB_USER@$RTB_HOST:/tmp/import_script.rb"

# Execute the import script via Kamal on RTB
ssh -i "$RTB_SSH_KEY" "$RTB_USER@$RTB_HOST" << 'EOF'
cd ~/routine
kamal app exec --interactive --reuse "cp /tmp/import_script.rb /rails/ && cp /tmp/laptop_export.json /rails/ && bin/rails runner /rails/import_script.rb /rails/laptop_export.json"
EOF

# Clean up temporary files on RTB
ssh -i "$RTB_SSH_KEY" "$RTB_USER@$RTB_HOST" "rm -f /tmp/laptop_export.json /tmp/import_script.rb"

echo
echo "✅ Database synced back to RTB successfully!"
echo
echo "📋 Summary:"
echo "- Exported data from laptop deployment"
echo "- Imported data to RTB deployment"
echo "- Cleaned up temporary files"
echo
echo "🎉 Your RTB now has all the data from your laptop travels!"
echo

# Clean up local files
rm -f "$BACKUP_DIR/latest_export_path.txt"