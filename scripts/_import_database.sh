#!/bin/bash

#
# Internal Helper: Import Database
#
# This script imports a database export to a specific deployment.
# Used internally by transfer_flag.sh - not meant to be called directly.
#
# Usage: ./_import_database.sh [home.local|localhost] [input_file]
#

set -e

HOST=$1
INPUT_FILE=$2
PI_HOST="home.local"
PI_USER="joe"
SSH_KEY="~/.ssh/home.local"

# Helper functions for Pi operations using Docker directly (Pi doesn't have Kamal)
pi_get_container() {
    ssh -i "$SSH_KEY" "$PI_USER@$PI_HOST" "docker ps --format '{{.Names}}' | grep routine" 2>/dev/null | head -1
}

pi_rails_exec_with_input() {
    local rails_command="$1"
    local input="$2"
    local container_name
    container_name=$(pi_get_container)
    if [ -n "$container_name" ]; then
        ssh -i "$SSH_KEY" "$PI_USER@$PI_HOST" "echo '$input' | docker exec -i $container_name bin/rails $rails_command" 2>&1
    else
        echo "No container found"
        return 1
    fi
}

if [ -z "$HOST" ] || [ -z "$INPUT_FILE" ]; then
    echo "Usage: $0 [home.local|localhost] [input_file]"
    exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
    echo "❌ Import file not found: $INPUT_FILE"
    exit 1
fi

echo "📥 Importing database to $HOST..."
echo "📁 From file: $INPUT_FILE"

if [ "$HOST" = "$PI_HOST" ]; then
    # Import to Pi using Docker directly
    echo "🔗 Uploading to Pi via SSH..."
    
    # Copy file to Pi and import using Docker
    scp -i "$SSH_KEY" "$INPUT_FILE" "$PI_USER@$HOST:/tmp/db_import.json" && \
    pi_rails_exec_with_input "db:sync:import[/tmp/db_import.json]" "y" && \
    ssh -i "$SSH_KEY" "$PI_USER@$HOST" "rm -f /tmp/db_import.json"
    
elif [ "$HOST" = "localhost" ]; then
    # Import to laptop
    echo "💻 Importing to local deployment..."
    
    # Try Kamal first, fall back to Docker direct if SSH fails
    container_name=$(docker ps -a --format '{{.Names}}' | grep routine | head -1)
    
    if [ -n "$container_name" ]; then
        echo "📦 Using Docker directly with container: $container_name"
        
        # Check if container is running, start it if not
        if [ "$(docker inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null)" != "running" ]; then
            echo "🔄 Starting stopped container..."
            # Temporarily create flag to allow container to start
            docker run --rm -v survey_storage_local:/tmp/storage alpine sh -c 'echo "Temporary flag for import" > /tmp/storage/ACTIVE_FLAG'
            docker start "$container_name"
            # Wait a moment for container to start
            sleep 5
        fi
        
        # Ensure container is ready for import by creating temporary flag if needed
        if ! docker exec "$container_name" test -f /rails/storage/ACTIVE_FLAG 2>/dev/null; then
            echo "🔧 Creating temporary flag for import..."
            docker exec "$container_name" sh -c 'echo "Temporary flag for import" > /rails/storage/ACTIVE_FLAG'
        fi
        
        # Copy file to container and run import using Docker directly
        docker cp "$INPUT_FILE" "$container_name:/rails/tmp/db_import.json"
        echo "y" | docker exec -i "$container_name" bin/rails db:sync:import[/rails/tmp/db_import.json]
        docker exec "$container_name" rm -f /rails/tmp/db_import.json || true
        
        # Remove temporary flag after import
        docker exec "$container_name" rm -f /rails/storage/ACTIVE_FLAG || true
    else
        echo "⚠️  No running container found, trying Kamal commands..."
        # Try Kamal as fallback (in case SSH is working)
        kamal app exec -d local --reuse "cat > /rails/tmp/db_import.json" < "$INPUT_FILE"
        echo "y" | kamal app exec -d local --reuse "bin/rails db:sync:import[/rails/tmp/db_import.json]"
        kamal app exec -d local --reuse "rm -f /rails/tmp/db_import.json" || true
    fi
    
else
    echo "❌ Unknown host: $HOST"
    exit 1
fi

echo "✅ Database imported to $HOST successfully"