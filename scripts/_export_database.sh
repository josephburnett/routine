#!/bin/bash

#
# Database Export v2 - SQLite Native Tools
#
# This script exports the complete database using SQLite's native .dump command
# which captures ALL data automatically - no hardcoded model lists required.
#
# Usage: ./_export_database_v2.sh [home.local|localhost] [output_file]
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

echo "📦 Exporting database from $HOST using SQLite native tools..."
echo "📁 Output file: $OUTPUT_FILE"

if [ "$HOST" = "$PI_HOST" ]; then
    # Export from Pi using SSH
    echo "🔗 Connecting to Pi via SSH..."
    
    # Create remote export and copy it locally
    remote_export="/tmp/db_export_$(date +%Y%m%d_%H%M%S).sql"
    
    # Check if container is running
    container_name=$(ssh -i "$SSH_KEY" "$PI_USER@$HOST" "docker ps --format '{{.Names}}' | grep routine | head -1" 2>/dev/null)
    
    if [ -n "$container_name" ]; then
        # Container is running - export via container
        echo "📦 Exporting via running container: $container_name"
        ssh -i "$SSH_KEY" "$PI_USER@$HOST" "docker exec $container_name sqlite3 /rails/storage/production.sqlite3 '.dump'" > "$OUTPUT_FILE"
    else
        # Container is stopped - use minimal SQLite container for direct export
        echo "📦 Container stopped, using minimal SQLite container for export..."
        
        # Export directly from volume using lightweight SQLite container
        # Redirect apk output to /dev/null to avoid contaminating SQL dump
        ssh -i "$SSH_KEY" "$PI_USER@$HOST" "docker run --rm -v survey_storage:/data alpine sh -c 'apk add --no-cache sqlite >/dev/null 2>&1 && sqlite3 /data/production.sqlite3 .dump'" > "$OUTPUT_FILE"
        
        if [ $? -ne 0 ]; then
            echo "❌ Failed to export database using SQLite container"
            exit 1
        fi
    fi
    
    if [ $? -eq 0 ] && [ -s "$OUTPUT_FILE" ]; then
        file_size=$(du -h "$OUTPUT_FILE" | cut -f1)
        echo "✅ Database exported successfully"
        echo "💾 Size: $file_size"
        
        # Verify the export contains essential tables
        if grep -q "CREATE TABLE.*users" "$OUTPUT_FILE" && grep -q "CREATE TABLE.*reports" "$OUTPUT_FILE"; then
            echo "✅ Export verification: Essential tables found"
        else
            echo "⚠️  Export verification: Some expected tables missing"
        fi
    else
        echo "❌ Database export failed"
        exit 1
    fi
    
elif [ "$HOST" = "localhost" ]; then
    # Export from localhost container
    echo "💻 Exporting from local deployment..."
    
    # Check for running container first
    container_name=$(docker ps --format '{{.Names}}' | grep routine | head -1)
    
    if [ -z "$container_name" ]; then
        # No running container, check for stopped containers
        echo "📦 No running container found, checking for stopped containers..."
        stopped_container=$(docker ps -a --format '{{.Names}}' | grep routine | head -1)
        
        if [ -n "$stopped_container" ]; then
            echo "📦 Container stopped, starting temporarily for export..."
            docker start "$stopped_container"
            sleep 5  # Give container time to start
            
            # Check if it started successfully
            if docker ps --format '{{.Names}}' | grep -q "$stopped_container"; then
                container_name="$stopped_container"
                should_stop_after=true
            else
                echo "❌ Failed to start stopped container for export"
                exit 1
            fi
        else
            echo "❌ No routine container found on localhost"
            exit 1
        fi
    fi
    
    # Export using SQLite .dump command
    docker exec "$container_name" sqlite3 /rails/storage/production.sqlite3 .dump > "$OUTPUT_FILE"
    
    # Stop container if we started it temporarily
    if [ "$should_stop_after" = "true" ]; then
        echo "📦 Stopping temporary container..."
        docker stop "$container_name" >/dev/null
    fi
    
    if [ $? -eq 0 ] && [ -s "$OUTPUT_FILE" ]; then
        file_size=$(du -h "$OUTPUT_FILE" | cut -f1)
        echo "✅ Database exported successfully"
        echo "💾 Size: $file_size"
        
        # Verify the export contains essential tables
        if grep -q "CREATE TABLE.*users" "$OUTPUT_FILE" && grep -q "CREATE TABLE.*reports" "$OUTPUT_FILE"; then
            echo "✅ Export verification: Essential tables found"
        else
            echo "⚠️  Export verification: Some expected tables missing"
        fi
    else
        echo "❌ Database export failed"
        exit 1
    fi
    
else
    echo "❌ Unknown host: $HOST"
    exit 1
fi

echo "✅ Database export completed: $OUTPUT_FILE"