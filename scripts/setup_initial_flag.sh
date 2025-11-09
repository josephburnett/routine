#!/bin/bash

#
# Setup Initial Flag
#
# This script sets up the initial flag for a new Flag Transfer System installation.
# Run this ONCE on whichever deployment is currently active and has your data.
#
# Usage: ./scripts/setup_initial_flag.sh
#

set -e

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

echo "🏁 Flag Transfer System - Initial Setup"
echo "======================================"
echo
log_info "This script sets up the initial flag for your Flag Transfer System."
log_info "Run this ONCE on the deployment that currently has your data."
echo

# Detect current environment
current_host=$(hostname)
if [ "$current_host" = "rtb.gila-lionfish.ts.net" ] || echo "$current_host" | grep -q "raspberrypi"; then
    suggested_deployment="RTB (rtb.gila-lionfish.ts.net)"
    deployment_type="pi"
elif [ -f /.dockerenv ] || [ "$current_host" = "localhost" ]; then
    suggested_deployment="Laptop (localhost)"
    deployment_type="laptop"
else
    suggested_deployment="Unknown"
    deployment_type="unknown"
fi

log_info "Detected environment: $suggested_deployment"
echo

# Check if flag already exists
if [ "$deployment_type" = "pi" ]; then
    # Check RTB deployment
    if ssh -i ~/.ssh/rtb.local joe@rtb.gila-lionfish.ts.net "cd ~/routine && kamal app exec --reuse 'test -f /rails/storage/ACTIVE_FLAG'" 2>/dev/null; then
        log_warning "Flag already exists on RTB deployment"
        log_info "Current flag status:"
        ssh -i ~/.ssh/rtb.local joe@rtb.gila-lionfish.ts.net "cd ~/routine && kamal app exec --reuse 'bin/rails flag:status'" 2>/dev/null || true
        echo
        log_info "If you want to reset the flag system, use: ./scripts/transfer_flag.sh --status"
        exit 0
    fi
elif [ "$deployment_type" = "laptop" ]; then
    # Check laptop deployment
    if kamal app exec -d local --reuse "test -f /rails/storage/ACTIVE_FLAG" 2>/dev/null; then
        log_warning "Flag already exists on laptop deployment"
        log_info "Current flag status:"
        kamal app exec -d local --reuse "bin/rails flag:status" 2>/dev/null || true
        echo
        log_info "If you want to reset the flag system, use: ./scripts/transfer_flag.sh --status"
        exit 0
    fi
fi

# Confirmation
echo "🎯 Setup Options:"
echo "1. RTB (rtb.gila-lionfish.ts.net) - Set flag on Raspberry RTB deployment"
echo "2. Laptop (localhost) - Set flag on laptop deployment"
echo "3. Check status - See current flag status on both deployments"
echo "4. Cancel - Exit without making changes"
echo

printf "Choose option (1-4): "
read -r choice

case $choice in
    1)
        target="pi"
        target_name="RTB (rtb.gila-lionfish.ts.net)"
        ;;
    2)
        target="laptop"
        target_name="Laptop (localhost)"
        ;;
    3)
        log_info "Checking current flag status..."
        if command -v ./scripts/transfer_flag.sh >/dev/null 2>&1; then
            ./scripts/transfer_flag.sh --status
        else
            log_warning "transfer_flag.sh not found, checking manually..."
            # Manual check logic here if needed
        fi
        exit 0
        ;;
    4)
        log_info "Setup cancelled"
        exit 0
        ;;
    *)
        log_error "Invalid choice: $choice"
        exit 1
        ;;
esac

echo
log_warning "This will create the initial flag on: $target_name"
log_warning "This deployment will become the 'active' deployment."
log_warning "The other deployment will be unable to start until you transfer the flag."
echo
printf "Continue? (y/N): "
read -r confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    log_info "Setup cancelled"
    exit 0
fi

# Create flag on chosen deployment
log_info "Creating initial flag on $target_name..."

if [ "$target" = "pi" ]; then
    # Create flag on RTB
    if ! ping -c 1 -W 2 rtb.gila-lionfish.ts.net >/dev/null 2>&1; then
        log_error "Cannot reach rtb.gila-lionfish.ts.net"
        log_info "Make sure you're on the same network as your RTB"
        exit 1
    fi
    
    if ! ssh -i ~/.ssh/rtb.local joe@rtb.gila-lionfish.ts.net "cd ~/routine && kamal app logs >/dev/null 2>&1" 2>/dev/null; then
        log_error "RTB deployment not running or not accessible"
        log_info "Make sure your RTB deployment is running first:"
        log_info "  ssh -i ~/.ssh/rtb.local joe@rtb.gila-lionfish.ts.net"
        log_info "  cd ~/routine && kamal deploy"
        exit 1
    fi
    
    ssh -i ~/.ssh/rtb.local joe@rtb.gila-lionfish.ts.net "cd ~/routine && kamal app exec --reuse 'bin/rails flag:create[\"Initial setup\"]'"
    
elif [ "$target" = "laptop" ]; then
    # Create flag on laptop
    if ! kamal app logs -d local >/dev/null 2>&1; then
        log_error "Laptop deployment not running"
        log_info "Make sure your local deployment is running first:"
        log_info "  kamal deploy -d local"
        exit 1
    fi
    
    kamal app exec -d local --reuse "bin/rails flag:create[\"Initial setup\"]"
fi

log_success "Initial flag created successfully!"
echo
log_info "🎉 Flag Transfer System is now active"
log_info "📍 Active deployment: $target_name"
echo
if [ "$target" = "pi" ]; then
    log_info "Your app is running at: http://rtb.gila-lionfish.ts.net:10001"
    log_info "To transfer to laptop: ./scripts/transfer_flag.sh localhost"
else
    log_info "Your app is running at: http://localhost:8080"
    log_info "To transfer to RTB: ./scripts/transfer_flag.sh rtb.gila-lionfish.ts.net"
fi
echo
log_info "Check status anytime with: ./scripts/transfer_flag.sh --status"
log_info "See FLAG_TRANSFER_GUIDE.md for complete documentation"