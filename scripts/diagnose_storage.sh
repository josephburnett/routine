#!/bin/bash

#
# Diagnose Storage and Volume Setup
#
# This script investigates the current Docker volume setup on the Pi
# to understand why the flag isn't persisting across deployments.
#
# Usage: ./scripts/diagnose_storage.sh
#

set -e

# Configuration
PI_HOST="home.local"
PI_USER="joe"
SSH_KEY="~/.ssh/home.local"

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

echo "🔍 Storage and Volume Diagnosis"
echo "==============================="
echo

# Check Pi connectivity
log_info "Checking connectivity to Pi ($PI_HOST)..."
if ! ping -c 1 -W 2 "$PI_HOST" >/dev/null 2>&1; then
    log_error "Cannot ping $PI_HOST"
    exit 1
fi
log_success "Pi connectivity verified"

# Get container information
log_info "Finding routine containers on Pi..."
CONTAINERS=$(ssh -i "$SSH_KEY" "$PI_USER@$PI_HOST" "docker ps --format '{{.Names}}' | grep routine" 2>/dev/null || echo "")

if [ -z "$CONTAINERS" ]; then
    log_warning "No routine containers currently running"
    log_info "Checking stopped containers..."
    CONTAINERS=$(ssh -i "$SSH_KEY" "$PI_USER@$PI_HOST" "docker ps -a --format '{{.Names}}' | grep routine" 2>/dev/null || echo "")
    if [ -z "$CONTAINERS" ]; then
        log_error "No routine containers found at all"
        exit 1
    fi
fi

echo "$CONTAINERS" | while read -r container; do
    if [ -n "$container" ]; then
        echo
        log_info "=== Container: $container ==="
        
        # Check if container is running
        IS_RUNNING=$(ssh -i "$SSH_KEY" "$PI_USER@$PI_HOST" "docker inspect --format='{{.State.Running}}' $container" 2>/dev/null || echo "false")
        log_info "Running: $IS_RUNNING"
        
        # Check volume mounts
        log_info "Volume mounts:"
        ssh -i "$SSH_KEY" "$PI_USER@$PI_HOST" "docker inspect --format='{{range .Mounts}}{{.Type}}: {{.Source}} -> {{.Destination}}{{println}}{{end}}' $container" 2>/dev/null || log_warning "Could not inspect mounts"
        
        # Check if storage directory exists and what's in it
        if [ "$IS_RUNNING" = "true" ]; then
            log_info "Storage directory contents:"
            ssh -i "$SSH_KEY" "$PI_USER@$PI_HOST" "docker exec $container ls -la /rails/storage/ 2>/dev/null || echo 'Storage directory not accessible'" || log_warning "Could not list storage"
            
            # Check for flag file specifically
            log_info "Checking for ACTIVE_FLAG:"
            if ssh -i "$SSH_KEY" "$PI_USER@$PI_HOST" "docker exec $container test -f /rails/storage/ACTIVE_FLAG" 2>/dev/null; then
                log_success "ACTIVE_FLAG found in $container"
                ssh -i "$SSH_KEY" "$PI_USER@$PI_HOST" "docker exec $container cat /rails/storage/ACTIVE_FLAG" 2>/dev/null || log_warning "Could not read flag content"
            else
                log_warning "ACTIVE_FLAG not found in $container"
            fi
        else
            log_warning "Container not running - cannot check internal storage"
        fi
    fi
done

echo
log_info "=== Docker Volumes on Pi ==="
ssh -i "$SSH_KEY" "$PI_USER@$PI_HOST" "docker volume ls" 2>/dev/null || log_warning "Could not list volumes"

# Check for the specific volume mentioned in deploy.yml
echo
log_info "=== Survey Storage Volume ==="
VOLUME_EXISTS=$(ssh -i "$SSH_KEY" "$PI_USER@$PI_HOST" "docker volume ls -q | grep survey_storage" 2>/dev/null || echo "")
if [ -n "$VOLUME_EXISTS" ]; then
    log_success "survey_storage volume found"
    
    # Try to inspect the volume
    log_info "Volume details:"
    ssh -i "$SSH_KEY" "$PI_USER@$PI_HOST" "docker volume inspect survey_storage" 2>/dev/null || log_warning "Could not inspect volume"
    
    # Try to see what's in the volume using a temporary container
    log_info "Volume contents (via temporary container):"
    ssh -i "$SSH_KEY" "$PI_USER@$PI_HOST" "docker run --rm -v survey_storage:/data alpine ls -la /data" 2>/dev/null || log_warning "Could not examine volume contents"
    
else
    log_warning "survey_storage volume not found"
fi

echo
log_info "=== Local Deploy Config Volume Setting ==="
VOLUME_CONFIG=$(ssh -i "$SSH_KEY" "$PI_USER@$PI_HOST" "grep -A5 -B5 'survey_storage' ~/routine/config/deploy.yml" 2>/dev/null || echo "Config not found")
if [ -n "$VOLUME_CONFIG" ]; then
    log_info "Volume configuration from deploy.yml:"
    echo "$VOLUME_CONFIG"
else
    log_warning "Could not find volume configuration"
fi

echo
log_success "Diagnosis complete!"
echo
log_info "Key Questions:"
log_info "1. Are containers using the survey_storage volume?"
log_info "2. Is the volume properly mounted to /rails/storage?"
log_info "3. Is the flag being created in the right location?"
log_info "4. Does the volume persist across container recreation?"