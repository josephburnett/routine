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
    
    # Copy file to container and run import (with auto-confirmation)
    kamal app exec -d local --reuse "cat > /rails/tmp/db_import.json" < "$INPUT_FILE"
    echo "y" | kamal app exec -d local --reuse "bin/rails db:sync:import[/rails/tmp/db_import.json]"
    kamal app exec -d local --reuse "rm -f /rails/tmp/db_import.json" || true
    
else
    echo "❌ Unknown host: $HOST"
    exit 1
fi

echo "✅ Database imported to $HOST successfully"