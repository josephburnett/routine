#!/bin/bash

#
# Bootstrap Flag on Pi
#
# This script manually creates the ACTIVE_FLAG file on your existing Pi deployment
# to bootstrap the flag transfer system. Use this when your Pi has the latest data
# but the new flag validation code prevents deployment.
#
# Usage: ./scripts/bootstrap_flag_on_pi.sh
#

set -e

# Configuration
PI_HOST="home.taile52c2f.ts.net"
PI_USER="joe"
# SSH_KEY no longer needed with Tailscale SSH

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

echo "🏁 Bootstrap Flag on Pi"
echo "======================"
echo
log_info "This script manually creates the ACTIVE_FLAG file on your Pi deployment"
log_info "to bootstrap the flag transfer system."
echo

# Check Pi connectivity
log_info "Checking connectivity to Pi ($PI_HOST)..."
if ! ping -c 1 -W 2 "$PI_HOST" >/dev/null 2>&1; then
    log_error "Cannot ping $PI_HOST"
    log_info "Make sure you're on the same network as your Pi"
    exit 1
fi

if ! ssh -o ConnectTimeout=5 "$PI_USER@$PI_HOST" "echo 'SSH OK'" >/dev/null 2>&1; then
    log_error "Cannot SSH to $PI_HOST"
    log_info "Check your SSH key and Pi connectivity"
    exit 1
fi
log_success "Pi connectivity verified"

# Check if Pi has Docker containers running
log_info "Checking Pi Docker containers..."
CONTAINER_NAME=$(ssh "$PI_USER@$PI_HOST" "docker ps --format '{{.Names}}' | grep routine" 2>/dev/null | head -1)

if [ -z "$CONTAINER_NAME" ]; then
    log_error "No routine containers found on Pi"
    log_info "Make sure your Pi deployment is running. From your main machine:"
    log_info "  kamal deploy"
    log_info "Or check what containers are running on Pi:"
    log_info "  ssh $PI_USER@$PI_HOST 'docker ps'"
    exit 1
fi

log_success "Found routine container: $CONTAINER_NAME"

# Check if flag already exists
log_info "Checking if flag already exists..."
if ssh "$PI_USER@$PI_HOST" "docker exec $CONTAINER_NAME test -f /rails/storage/ACTIVE_FLAG" 2>/dev/null; then
    log_warning "Flag already exists on Pi!"
    log_info "Current flag content:"
    ssh "$PI_USER@$PI_HOST" "docker exec $CONTAINER_NAME cat /rails/storage/ACTIVE_FLAG" 2>/dev/null || echo "Could not read flag content"
    echo
    printf "Overwrite existing flag? (y/N): "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_info "Bootstrap cancelled - keeping existing flag"
        exit 0
    fi
fi

# Create flag file
log_info "Creating ACTIVE_FLAG file on Pi..."

# Generate flag content
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TRANSFER_ID="bootstrap_$(date +"%Y%m%d_%H%M%S")"

FLAG_CONTENT="ACTIVE_FLAG
Created: $TIMESTAMP
Host: home.taile52c2f.ts.net
Source: manual_bootstrap
Transfer ID: $TRANSFER_ID"

# Create the flag via SSH + Docker
ssh "$PI_USER@$PI_HOST" << EOF
docker exec $CONTAINER_NAME mkdir -p /rails/storage
docker exec $CONTAINER_NAME sh -c "cat > /rails/storage/ACTIVE_FLAG << 'FLAGEOF'
$FLAG_CONTENT
FLAGEOF"
EOF

# Verify flag creation
log_info "Verifying flag creation..."
if ssh "$PI_USER@$PI_HOST" "docker exec $CONTAINER_NAME test -f /rails/storage/ACTIVE_FLAG" 2>/dev/null; then
    log_success "Flag created successfully!"
    echo
    log_info "Flag content:"
    ssh "$PI_USER@$PI_HOST" "docker exec $CONTAINER_NAME cat /rails/storage/ACTIVE_FLAG" 2>/dev/null || echo "Could not read flag content"
else
    log_error "Flag creation failed!"
    exit 1
fi

echo
log_success "🎉 Pi bootstrap completed successfully!"
echo
log_info "Next steps:"
log_info "1. Deploy your new code with flag validation:"
log_info "   kamal deploy"
log_info ""
log_info "2. Test the new flag system:"
log_info "   kamal app exec --reuse 'bin/rails flag:status'"
log_info "   OR directly: ssh $PI_USER@$PI_HOST 'docker exec $CONTAINER_NAME bin/rails flag:status'"
log_info ""
log_info "3. Check transfer system status:"
log_info "   ./scripts/transfer_flag.sh --status"
echo
log_info "Your Pi now has the flag and is the active deployment!"
log_info "The flag transfer system is ready to use."