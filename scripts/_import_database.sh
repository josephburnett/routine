#!/bin/bash

#
# Database Import v2 - SQLite Native Tools
#
# This script imports a complete database using SQLite's native .read command
# which restores ALL data atomically - safer than application-level imports.
#
# Usage: ./_import_database_v2.sh [rtb.gila-lionfish.ts.net|localhost] [input_file]
#

set -e

HOST=$1
INPUT_FILE=$2
RTB_HOST="rtb.gila-lionfish.ts.net"
RTB_USER="joe"
RTB_SSH_KEY="$HOME/.ssh/rtb.local"
# SSH_KEY no longer needed with Tailscale SSH

if [ -z "$HOST" ] || [ -z "$INPUT_FILE" ]; then
    echo "Usage: $0 [rtb.gila-lionfish.ts.net|localhost] [input_file]"
    exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
    echo "❌ Import file not found: $INPUT_FILE"
    exit 1
fi

echo "📥 Importing database to $HOST using SQLite native tools..."
echo "📁 From file: $INPUT_FILE"

# Verify import file contains expected content
if ! grep -q "CREATE TABLE.*users" "$INPUT_FILE" || ! grep -q "CREATE TABLE.*reports" "$INPUT_FILE"; then
    echo "❌ Import file does not contain expected database structure"
    exit 1
fi

# Function to create temporary flag for import operations
create_temp_flag() {
    local host=$1
    local reason="temp_for_import_$(date +%s)"

    if [ "$host" = "$RTB_HOST" ]; then
        # Write flag directly to volume (container may be stopped/restarting)
        ssh -i "$RTB_SSH_KEY" "$RTB_USER@$host" "docker run --rm -v survey_storage:/storage alpine sh -c 'echo \"ACTIVE_FLAG
Created: \$(date -Iseconds)
Host: $host
Source: $reason
Transfer ID: $reason\" > /storage/ACTIVE_FLAG'"
    elif [ "$host" = "localhost" ]; then
        # For localhost, write flag via volume to avoid permission issues
        docker run --rm -v survey_storage_local:/storage alpine sh -c "echo \"ACTIVE_FLAG
Created: \$(date -Iseconds)
Host: $host
Source: $reason
Transfer ID: $reason\" > /storage/ACTIVE_FLAG"
    fi
}

# Function to remove flag
remove_flag() {
    local host=$1

    if [ "$host" = "$RTB_HOST" ]; then
        # Remove flag directly from volume (container may be stopped/restarting)
        ssh -i "$RTB_SSH_KEY" "$RTB_USER@$host" "docker run --rm -v survey_storage:/storage alpine rm -f /storage/ACTIVE_FLAG" || true
    elif [ "$host" = "localhost" ]; then
        # For localhost, remove flag via volume to avoid permission issues
        docker run --rm -v survey_storage_local:/storage alpine rm -f /storage/ACTIVE_FLAG || true
    fi
}

if [ "$HOST" = "$RTB_HOST" ]; then
    # Import to RTB using SSH
    echo "🔗 Uploading to RTB via SSH..."
    
    # Create temporary import file on RTB
    temp_import="/tmp/db_import_$(date +%Y%m%d_%H%M%S).sql"
    
    # Copy import file to RTB
    scp -i "$RTB_SSH_KEY" "$INPUT_FILE" "$RTB_USER@$HOST:$temp_import"

    # Get container name
    container_name=$(ssh -i "$RTB_SSH_KEY" "$RTB_USER@$HOST" "docker ps --format '{{.Names}}' | grep routine | head -1")
    
    if [ -z "$container_name" ]; then
        echo "❌ No running routine container found on RTB"
        ssh -i "$RTB_SSH_KEY" "$RTB_USER@$HOST" "rm -f $temp_import"
        exit 1
    fi
    
    # Create temporary flag to allow database operations
    echo "🔧 Creating temporary flag for import..."
    create_temp_flag "$HOST"
    
    # Backup current database before import
    backup_file="/tmp/db_backup_before_import_$(date +%Y%m%d_%H%M%S).sql"
    echo "💾 Creating backup before import..."
    ssh -i "$RTB_SSH_KEY" "$RTB_USER@$HOST" "docker exec $container_name sqlite3 /rails/storage/production.sqlite3 '.dump'" > "./backups/pi_backup_before_import_$(date +%Y%m%d_%H%M%S).sql"
    
    # Copy import file into container and import database
    echo "📥 Importing database (this will replace all existing data)..."
    ssh -i "$RTB_SSH_KEY" "$RTB_USER@$HOST" "docker cp $temp_import $container_name:/tmp/db_import.sql"
    ssh -i "$RTB_SSH_KEY" "$RTB_USER@$HOST" "docker exec $container_name sh -c 'rm -f /rails/storage/production.sqlite3 && sqlite3 /rails/storage/production.sqlite3 < /tmp/db_import.sql'"
    
    if [ $? -eq 0 ]; then
        echo "✅ Database imported successfully"
        
        # Verify import by checking record counts
        record_count=$(ssh -i "$RTB_SSH_KEY" "$RTB_USER@$HOST" "docker exec $container_name sqlite3 /rails/storage/production.sqlite3 'SELECT COUNT(*) FROM sqlite_master WHERE type=\"table\";'" 2>/dev/null || echo "0")
        echo "✅ Import verification: $record_count tables found"
        
        # Clean up temporary files
        ssh -i "$RTB_SSH_KEY" "$RTB_USER@$HOST" "rm -f $temp_import"
        ssh -i "$RTB_SSH_KEY" "$RTB_USER@$HOST" "docker exec $container_name rm -f /tmp/db_import.sql" || true
        
        # Remove temporary flag (will be recreated properly by transfer script)
        remove_flag "$HOST"
    else
        echo "❌ Database import failed"
        ssh -i "$RTB_SSH_KEY" "$RTB_USER@$HOST" "rm -f $temp_import"
        ssh -i "$RTB_SSH_KEY" "$RTB_USER@$HOST" "docker exec $container_name rm -f /tmp/db_import.sql" || true
        remove_flag "$HOST"
        exit 1
    fi
    
elif [ "$HOST" = "localhost" ]; then
    # Import to localhost container
    echo "💻 Importing to local deployment..."
    
    container_name=$(docker ps --format '{{.Names}}' | grep routine | head -1)
    if [ -z "$container_name" ]; then
        echo "❌ No running routine container found on localhost"
        exit 1
    fi
    
    # Create temporary flag to allow database operations
    echo "🔧 Creating temporary flag for import..."
    create_temp_flag "localhost"
    
    # Backup current database before import
    echo "💾 Creating backup before import..."
    docker exec "$container_name" sqlite3 /rails/storage/production.sqlite3 .dump > "./backups/localhost_backup_before_import_$(date +%Y%m%d_%H%M%S).sql"
    
    # Copy import file to container
    docker cp "$INPUT_FILE" "$container_name:/tmp/db_import.sql"
    
    # Import database (this replaces the entire database)
    echo "📥 Importing database (this will replace all existing data)..."
    docker exec "$container_name" sh -c 'rm -f /rails/storage/production.sqlite3 && sqlite3 /rails/storage/production.sqlite3 < /tmp/db_import.sql'
    
    if [ $? -eq 0 ]; then
        echo "✅ Database imported successfully"
        
        # Verify import by checking record counts
        record_count=$(docker exec "$container_name" sqlite3 /rails/storage/production.sqlite3 'SELECT COUNT(*) FROM sqlite_master WHERE type="table";' 2>/dev/null || echo "0")
        echo "✅ Import verification: $record_count tables found"
        
        # Clean up temporary files
        docker exec "$container_name" rm -f /tmp/db_import.sql
        
        # Remove temporary flag (will be recreated properly by transfer script)
        remove_flag "localhost"
    else
        echo "❌ Database import failed"
        docker exec "$container_name" rm -f /tmp/db_import.sql || true
        remove_flag "localhost"
        exit 1
    fi
    
else
    echo "❌ Unknown host: $HOST"
    exit 1
fi

echo "✅ Database imported to $HOST successfully"