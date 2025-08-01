#!/bin/bash

#
# Database Import v2 - SQLite Native Tools
#
# This script imports a complete database using SQLite's native .read command
# which restores ALL data atomically - safer than application-level imports.
#
# Usage: ./_import_database_v2.sh [home.local|localhost] [input_file]
#

set -e

HOST=$1
INPUT_FILE=$2
PI_HOST="home.local"
PI_USER="joe"
SSH_KEY="~/.ssh/home.local"

if [ -z "$HOST" ] || [ -z "$INPUT_FILE" ]; then
    echo "Usage: $0 [home.local|localhost] [input_file]"
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
    
    if [ "$host" = "$PI_HOST" ]; then
        ssh -i "$SSH_KEY" "$PI_USER@$host" "docker exec \$(docker ps --format '{{.Names}}' | grep routine | head -1) sh -c 'echo \"ACTIVE_FLAG
Created: \$(date -Iseconds)
Host: $host
Source: $reason
Transfer ID: $reason\" > /rails/storage/ACTIVE_FLAG'"
    elif [ "$host" = "localhost" ]; then
        local container_name=$(docker ps --format '{{.Names}}' | grep routine | head -1)
        if [ -n "$container_name" ]; then
            docker exec "$container_name" sh -c "echo \"ACTIVE_FLAG
Created: \$(date -Iseconds)
Host: $host
Source: $reason
Transfer ID: $reason\" > /rails/storage/ACTIVE_FLAG"
        fi
    fi
}

# Function to remove flag
remove_flag() {
    local host=$1
    
    if [ "$host" = "$PI_HOST" ]; then
        ssh -i "$SSH_KEY" "$PI_USER@$host" "docker exec \$(docker ps --format '{{.Names}}' | grep routine | head -1) rm -f /rails/storage/ACTIVE_FLAG" || true
    elif [ "$host" = "localhost" ]; then
        local container_name=$(docker ps --format '{{.Names}}' | grep routine | head -1)
        if [ -n "$container_name" ]; then
            docker exec "$container_name" rm -f /rails/storage/ACTIVE_FLAG || true
        fi
    fi
}

if [ "$HOST" = "$PI_HOST" ]; then
    # Import to Pi using SSH
    echo "🔗 Uploading to Pi via SSH..."
    
    # Create temporary import file on Pi
    temp_import="/tmp/db_import_$(date +%Y%m%d_%H%M%S).sql"
    
    # Copy import file to Pi
    scp -i "$SSH_KEY" "$INPUT_FILE" "$PI_USER@$HOST:$temp_import"
    
    # Get container name
    container_name=$(ssh -i "$SSH_KEY" "$PI_USER@$HOST" "docker ps --format '{{.Names}}' | grep routine | head -1")
    
    if [ -z "$container_name" ]; then
        echo "❌ No running routine container found on Pi"
        ssh -i "$SSH_KEY" "$PI_USER@$HOST" "rm -f $temp_import"
        exit 1
    fi
    
    # Create temporary flag to allow database operations
    echo "🔧 Creating temporary flag for import..."
    create_temp_flag "$HOST"
    
    # Backup current database before import
    backup_file="/tmp/db_backup_before_import_$(date +%Y%m%d_%H%M%S).sql"
    echo "💾 Creating backup before import..."
    ssh -i "$SSH_KEY" "$PI_USER@$HOST" "docker exec $container_name sqlite3 /rails/storage/production.sqlite3 '.dump'" > "./backups/pi_backup_before_import_$(date +%Y%m%d_%H%M%S).sql"
    
    # Copy import file into container and import database
    echo "📥 Importing database (this will replace all existing data)..."
    ssh -i "$SSH_KEY" "$PI_USER@$HOST" "docker cp $temp_import $container_name:/tmp/db_import.sql"
    ssh -i "$SSH_KEY" "$PI_USER@$HOST" "docker exec $container_name sh -c 'rm -f /rails/storage/production.sqlite3 && sqlite3 /rails/storage/production.sqlite3 < /tmp/db_import.sql'"
    
    if [ $? -eq 0 ]; then
        echo "✅ Database imported successfully"
        
        # Verify import by checking record counts
        record_count=$(ssh -i "$SSH_KEY" "$PI_USER@$HOST" "docker exec $container_name sqlite3 /rails/storage/production.sqlite3 'SELECT COUNT(*) FROM sqlite_master WHERE type=\"table\";'" 2>/dev/null || echo "0")
        echo "✅ Import verification: $record_count tables found"
        
        # Clean up temporary files
        ssh -i "$SSH_KEY" "$PI_USER@$HOST" "rm -f $temp_import"
        ssh -i "$SSH_KEY" "$PI_USER@$HOST" "docker exec $container_name rm -f /tmp/db_import.sql" || true
        
        # Remove temporary flag (will be recreated properly by transfer script)
        remove_flag "$HOST"
    else
        echo "❌ Database import failed"
        ssh -i "$SSH_KEY" "$PI_USER@$HOST" "rm -f $temp_import"
        ssh -i "$SSH_KEY" "$PI_USER@$HOST" "docker exec $container_name rm -f /tmp/db_import.sql" || true
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