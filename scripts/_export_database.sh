#!/bin/bash

#
# Internal Helper: Export Database
#
# This script exports the database from a specific deployment.
# Used internally by transfer_flag.sh - not meant to be called directly.
#
# Usage: ./_export_database.sh [home.local|localhost] [output_file]
#

set -e

HOST=$1
OUTPUT_FILE=$2
PI_HOST="home.local"
PI_USER="joe"
SSH_KEY="~/.ssh/home.local"

if [ -z "$HOST" ] || [ -z "$OUTPUT_FILE" ]; then
    echo "Usage: $0 [home.local|localhost] [output_file]"
    exit 1
fi

echo "📦 Exporting database from $HOST..."

if [ "$HOST" = "$PI_HOST" ]; then
    # Export from Pi
    echo "🔗 Connecting to Pi via SSH..."
    
    # Ensure Pi app is running for export
    ssh -i "$SSH_KEY" "$PI_USER@$HOST" "cd ~/routine && kamal app start" >/dev/null 2>&1 || true
    sleep 5
    
    # Run export
    ssh -i "$SSH_KEY" "$PI_USER@$HOST" "cd ~/routine && kamal app exec --reuse 'bin/rails db:sync:export'" >/dev/null
    
    # Find and download the export file
    REMOTE_EXPORT=$(ssh -i "$SSH_KEY" "$PI_USER@$HOST" "ls -t ~/routine/tmp/db_sync/db_export_*.json 2>/dev/null | head -1" || echo "")
    
    if [ -z "$REMOTE_EXPORT" ]; then
        echo "❌ No export file found on Pi"
        exit 1
    fi
    
    scp -i "$SSH_KEY" "$PI_USER@$HOST:$REMOTE_EXPORT" "$OUTPUT_FILE"
    
    # Clean up remote export file
    ssh -i "$SSH_KEY" "$PI_USER@$HOST" "rm -f $REMOTE_EXPORT" || true
    
elif [ "$HOST" = "localhost" ]; then
    # Export from laptop
    echo "💻 Exporting from local deployment..."
    
    # Ensure local app is running for export
    kamal app start -d local >/dev/null 2>&1 || true
    sleep 5
    
    # Run export
    kamal app exec -d local --reuse "bin/rails db:sync:export" >/dev/null
    
    # Find and copy export file from container
    LOCAL_EXPORT_PATH=$(kamal app exec -d local --reuse "ls -t /rails/tmp/db_sync/db_export_*.json 2>/dev/null | head -1" | tr -d '\r\n' || echo "")
    
    if [ -z "$LOCAL_EXPORT_PATH" ]; then
        echo "❌ No export file found in local container"
        exit 1
    fi
    
    kamal app exec -d local --reuse "cat $LOCAL_EXPORT_PATH" > "$OUTPUT_FILE"
    
    # Clean up container export file
    kamal app exec -d local --reuse "rm -f $LOCAL_EXPORT_PATH" || true
    
else
    echo "❌ Unknown host: $HOST"
    exit 1
fi

if [ ! -s "$OUTPUT_FILE" ]; then
    echo "❌ Export failed - output file is empty or missing"
    exit 1
fi

echo "✅ Database exported to $OUTPUT_FILE"
echo "💾 Size: $(du -h "$OUTPUT_FILE" | cut -f1)"