#!/bin/bash

#
# Laptop Restart Script
#
# This script helps restart your laptop deployment after a reboot.
# It's designed to work with the flag transfer system.
#
# Usage: ./scripts/laptop_restart.sh
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

# Help function
show_help() {
    cat << EOF
🔄 Laptop Restart Script

This script helps restart your laptop deployment after a reboot.
It checks if your laptop deployment should be active and restarts it if needed.

Usage:
  $0              Restart laptop deployment if it should be active
  $0 --force      Force restart regardless of flag status
  $0 --help       Show this help message

The script will:
1. Check if laptop should be active (has the flag)
2. Restart the deployment using Kamal if needed
3. Verify the deployment is working

EOF
}

# Check if deployment should be active
check_should_be_active() {
    # Check if survey_storage_local volume has an ACTIVE_FLAG
    if docker run --rm -v survey_storage_local:/storage alpine test -f /storage/ACTIVE_FLAG 2>/dev/null; then
        return 0  # Should be active
    else
        return 1  # Should not be active
    fi
}

# Check if deployment is currently running
check_is_running() {
    if curl -s --connect-timeout 2 --max-time 3 "http://localhost:3000/up" >/dev/null 2>&1; then
        return 0  # Is running
    else
        return 1  # Not running
    fi
}

# Restart the deployment
restart_deployment() {
    log_info "Validating 1Password authentication..."
    
    # Check if 1Password CLI is available and authenticated
    if ! op whoami >/dev/null 2>&1; then
        log_error "1Password CLI not authenticated. Please run:"
        log_error "  eval \$(op signin)"
        exit 1
    fi
    
    log_info "Restarting laptop deployment with Kamal..."
    
    if kamal deploy -d local --skip-push; then
        log_success "Deployment restarted successfully"
        
        # Wait for it to be ready
        log_info "Waiting for deployment to be ready..."
        local attempts=0
        local max_attempts=30
        
        while [ $attempts -lt $max_attempts ]; do
            if check_is_running; then
                log_success "Deployment is now running and responding"
                return 0
            fi
            sleep 1
            attempts=$((attempts + 1))
            if [ $((attempts % 5)) -eq 0 ]; then
                log_info "Still waiting... (${attempts}s)"
            fi
        done
        
        log_error "Deployment started but not responding after ${max_attempts}s"
        return 1
    else
        log_error "Failed to restart deployment"
        return 1
    fi
}

# Main function
main() {
    case "${1:-}" in
        "--help"|"-h")
            show_help
            exit 0
            ;;
        "--force")
            log_info "🔄 Force restarting laptop deployment..."
            restart_deployment
            ;;
        "")
            log_info "🔄 Checking laptop deployment status after reboot..."
            
            if check_should_be_active; then
                log_info "Laptop should be active (flag found)"
                
                if check_is_running; then
                    log_success "Deployment is already running"
                    curl -s http://localhost:3000/up >/dev/null && log_success "Application is responding correctly"
                else
                    log_warning "Deployment should be running but isn't - restarting..."
                    restart_deployment
                fi
            else
                log_info "Laptop should not be active (no flag found)"
                
                if check_is_running; then
                    log_warning "Deployment is running but shouldn't be"
                    log_info "This might be normal if containers have restart policies"
                    log_info "Use './scripts/transfer_flag.sh --status' to check system state"
                else
                    log_success "Deployment is correctly offline"
                fi
            fi
            ;;
        *)
            log_error "Invalid argument: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"