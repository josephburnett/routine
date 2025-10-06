#!/bin/bash

#
# Bootstrap Flag in Volume
#
# This script creates the ACTIVE_FLAG directly in the Docker volume
# to ensure it persists across container deployments.
#
# Usage: ./scripts/bootstrap_flag_volume.sh
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

echo "🏁 Bootstrap Flag in Docker Volume"
echo "=================================="
echo
log_info "This script creates the ACTIVE_FLAG directly in the Docker volume"
log_info "to ensure it persists across container deployments."
echo

# Check Pi connectivity
log_info "Checking connectivity to Pi ($PI_HOST)..."
if ! ping -c 1 -W 2 "$PI_HOST" >/dev/null 2>&1; then
    log_error "Cannot ping $PI_HOST"
    exit 1
fi
log_success "Pi connectivity verified"

# Check if volume exists
log_info "Checking for survey_storage volume..."
VOLUME_EXISTS=$(ssh "$PI_USER@$PI_HOST" "docker volume ls -q | grep survey_storage" 2>/dev/null || echo "")

if [ -z "$VOLUME_EXISTS" ]; then
    log_warning "survey_storage volume not found"
    log_info "Creating survey_storage volume..."
    ssh "$PI_USER@$PI_HOST" "docker volume create survey_storage"
    log_success "Volume created"
else
    log_success "survey_storage volume found"
fi

# Check if flag already exists in volume
log_info "Checking if flag already exists in volume..."
FLAG_EXISTS=$(ssh "$PI_USER@$PI_HOST" "docker run --rm -v survey_storage:/data alpine test -f /data/ACTIVE_FLAG && echo 'yes' || echo 'no'" 2>/dev/null)

if [ "$FLAG_EXISTS" = "yes" ]; then
    log_warning "Flag already exists in volume!"
    log_info "Current flag content:"
    ssh "$PI_USER@$PI_HOST" "docker run --rm -v survey_storage:/data alpine cat /data/ACTIVE_FLAG" 2>/dev/null || echo "Could not read flag content"
    echo
    printf "Overwrite existing flag? (y/N): "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_info "Bootstrap cancelled - keeping existing flag"
        exit 0
    fi
fi

# Create flag file in volume
log_info "Creating ACTIVE_FLAG file in volume..."

# Generate flag content
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TRANSFER_ID="bootstrap_volume_$(date +"%Y%m%d_%H%M%S")"

FLAG_CONTENT="ACTIVE_FLAG
Created: $TIMESTAMP
Host: home.taile52c2f.ts.net
Source: volume_bootstrap
Transfer ID: $TRANSFER_ID"

# Create the flag using a temporary container with volume mounted
ssh "$PI_USER@$PI_HOST" << EOF
docker run --rm -v survey_storage:/data alpine sh -c "cat > /data/ACTIVE_FLAG << 'FLAGEOF'
$FLAG_CONTENT
FLAGEOF"
EOF

# Verify flag creation
log_info "Verifying flag creation in volume..."
if ssh "$PI_USER@$PI_HOST" "docker run --rm -v survey_storage:/data alpine test -f /data/ACTIVE_FLAG" 2>/dev/null; then
    log_success "Flag created successfully in volume!"
    echo
    log_info "Flag content:"
    ssh "$PI_USER@$PI_HOST" "docker run --rm -v survey_storage:/data alpine cat /data/ACTIVE_FLAG" 2>/dev/null || echo "Could not read flag content"
else
    log_error "Flag creation failed!"
    exit 1
fi

echo
log_success "🎉 Volume bootstrap completed successfully!"
echo
log_info "The flag is now stored in the persistent Docker volume and will"
log_info "survive container deployments and recreations."
echo
log_info "Next steps:"
log_info "1. Deploy your new code with flag validation:"
log_info "   kamal deploy"
log_info ""
log_info "2. Test the new flag system:"
log_info "   kamal app exec --reuse 'bin/rails flag:status'"
log_info ""
log_info "3. Check transfer system status:"
log_info "   ./scripts/transfer_flag.sh --status"
echo
log_info "The flag should now persist across deployments!"