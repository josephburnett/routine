#!/bin/bash

#
# Backup RTB Database Script
# 
# This script exports the database from your Raspberry RTB to prepare for travel.
# Run this BEFORE leaving home to get the latest data for your laptop.
#
# Usage: ./scripts/backup_pi_database.sh
#

set -e

# Configuration
RTB_HOST="rtb.gila-lionfish.ts.net"
RTB_USER="joe"
RTB_SSH_KEY="$HOME/.ssh/rtb.local"
# SSH_KEY no longer needed with Tailscale SSH
BACKUP_DIR="./tmp/pi_backup"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

echo "🥧 Backing up database from Raspberry RTB..."
echo "Host: $RTB_HOST"
echo "Timestamp: $TIMESTAMP"
echo

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Function to run kamal commands on RTB
run_kamal_on_pi() {
    echo "📋 Running: kamal $*"
    kamal "$@"
}

# Create database export via Rails console on RTB
echo "📦 Creating database export on RTB..."
cat << 'EOF' > "$BACKUP_DIR/export_script.rb"
# Create a database export for travel
require 'json'
require 'fileutils'

puts "Starting database export..."

# Export all tables to JSON
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
export_file = "/rails/storage/db_export_#{Time.current.strftime('%Y%m%d_%H%M%S')}.json"
File.write(export_file, JSON.pretty_generate(export_data))

puts "Export completed: #{export_file}"
puts "Total size: #{File.size(export_file)} bytes"
EOF

# Copy script to RTB and execute via Kamal
echo "🚀 Executing export script on RTB..."
scp "$BACKUP_DIR/export_script.rb" "$RTB_USER@$RTB_HOST:/tmp/export_script.rb"

# Execute the export script via Kamal console
ssh -i "$RTB_SSH_KEY" "$RTB_USER@$RTB_HOST" << 'EOF'
cd ~/routine
kamal app exec --interactive --reuse "cp /tmp/export_script.rb /rails/ && bin/rails runner /rails/export_script.rb"
EOF

# Find and download the export file
echo "📥 Downloading export file from RTB..."
EXPORT_FILE=$(ssh -i "$RTB_SSH_KEY" "$RTB_USER@$RTB_HOST" "ls -t /home/joe/routine/storage/db_export_*.json | head -1")

if [ -z "$EXPORT_FILE" ]; then
    echo "❌ No export file found on RTB!"
    exit 1
fi

# Download the export file
LOCAL_EXPORT_FILE="$BACKUP_DIR/db_export_$TIMESTAMP.json"
scp "$RTB_USER@$RTB_HOST:$EXPORT_FILE" "$LOCAL_EXPORT_FILE"

# Also copy the actual SQLite files as backup
echo "📁 Copying SQLite database files..."
scp "$RTB_USER@$RTB_HOST:~/routine/storage/production*.sqlite3" "$BACKUP_DIR/" || true

echo
echo "✅ Backup completed successfully!"
echo "📁 Export file: $LOCAL_EXPORT_FILE"
echo "📁 SQLite files: $BACKUP_DIR/production*.sqlite3"
echo
echo "📋 Next steps:"
echo "1. Copy the export file to your laptop if running this on a different machine"
echo "2. Use './scripts/restore_to_laptop.sh' to import data to your laptop"
echo "3. Deploy locally with 'kamal deploy -d local'"
echo