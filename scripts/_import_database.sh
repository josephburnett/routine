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
    # Import to Pi
    echo "🔗 Uploading to Pi via SSH..."
    
    # Copy file to Pi
    scp -i "$SSH_KEY" "$INPUT_FILE" "$PI_USER@$HOST:/tmp/db_import.json"
    
    # Run import (with auto-confirmation)
    ssh -i "$SSH_KEY" "$PI_USER@$HOST" << 'EOF'
cd ~/routine
echo "y" | kamal app exec --reuse 'bin/rails db:sync:import[/tmp/db_import.json]'
rm -f /tmp/db_import.json
EOF
    
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