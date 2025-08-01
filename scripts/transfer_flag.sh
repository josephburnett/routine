#!/bin/bash

#
# Transfer Flag Script
#
# This script implements the "flag transfer" system that ensures only one deployment
# (Pi or laptop) is active at a time. The flag represents the authoritative database.
#
# Usage: 
#   ./scripts/transfer_flag.sh localhost      # Transfer flag from Pi to laptop
#   ./scripts/transfer_flag.sh home.local     # Transfer flag from laptop to Pi
#   ./scripts/transfer_flag.sh --status       # Check current flag status
#   ./scripts/transfer_flag.sh --dry-run TARGET # Preview what would happen
#

set -e

# Configuration
PI_HOST="home.local"
LAPTOP_HOST="localhost"
PI_USER="joe"
SSH_KEY="~/.ssh/home.local"
BACKUP_DIR="./tmp/flag_transfer"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

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

# Emergency rollback function
rollback_transfer() {
    local original_source=$1
    local failed_target=$2
    local backup_file=$3
    
    log_warning "🔄 Attempting emergency rollback..."
    log_info "  Original source: $original_source"
    log_info "  Failed target: $failed_target" 
    log_info "  Backup file: $backup_file"
    
    # Try to restart original source with its flag
    if [ "$original_source" = "$PI_HOST" ]; then
        log_info "Restarting Pi deployment..."
        pi_app_start || log_warning "Failed to restart Pi"
        pi_rails_exec "flag:force_create[\"Rollback from failed transfer\"]" >/dev/null || log_warning "Failed to restore Pi flag"
    else
        log_info "Restarting laptop deployment..."
        # For localhost, try Docker first, fall back to Kamal
        local container_name=$(docker ps -a --format '{{.Names}}' | grep routine | head -1)
        if [ -n "$container_name" ]; then
            docker start "$container_name" || log_warning "Failed to restart laptop"
            docker exec "$container_name" bin/rails flag:force_create["Rollback from failed transfer"] || log_warning "Failed to restore laptop flag"
        else
            kamal app start -d local || log_warning "Failed to restart laptop"
            kamal app exec -d local --reuse "bin/rails flag:force_create[\"Rollback from failed transfer\"]" || log_warning "Failed to restore laptop flag"
        fi
    fi
    
    log_warning "Rollback attempted. You may need to manually verify data integrity."
    log_info "Backup file preserved at: $backup_file"
}

# Help function
show_help() {
    cat << EOF
🏁 Flag Transfer System

Transfer the active flag between your Pi (home.local) and laptop (localhost).
Only one deployment can hold the flag at a time to prevent data conflicts.

Usage:
  $0 localhost         Transfer flag from Pi to laptop (for travel)
  $0 home.local        Transfer flag from laptop to Pi (returning home)
  $0 --status          Check current flag status on both deployments
  $0 --dry-run TARGET  Preview what would happen without making changes
  $0 --help            Show this help message

Examples:
  # Going on a trip - transfer to laptop
  $0 localhost
  
  # Returning home - transfer back to Pi
  $0 home.local
  
  # Check where the flag currently is
  $0 --status

The flag ensures only one deployment runs at a time, preventing accidental
data overwrites when switching between Pi and laptop deployments.
EOF
}

# Helper functions for Pi operations using Docker directly (Pi doesn't have Kamal)
pi_get_container() {
    ssh -i "$SSH_KEY" "$PI_USER@$PI_HOST" "docker ps --format '{{.Names}}' | grep routine" 2>/dev/null | head -1
}

pi_app_stop() {
    local container_name
    container_name=$(pi_get_container)
    if [ -n "$container_name" ]; then
        ssh -i "$SSH_KEY" "$PI_USER@$PI_HOST" "docker stop $container_name" 2>/dev/null || return 1
    fi
    return 0
}

pi_app_start() {
    # For Pi, we assume deployment exists and just restart the container
    local container_name
    container_name=$(ssh -i "$SSH_KEY" "$PI_USER@$PI_HOST" "docker ps -a --format '{{.Names}}' | grep routine" 2>/dev/null | head -1)
    if [ -n "$container_name" ]; then
        ssh -i "$SSH_KEY" "$PI_USER@$PI_HOST" "docker start $container_name" 2>/dev/null || return 1
    fi
    return 0
}

pi_rails_exec() {
    local rails_command="$1"
    local container_name
    container_name=$(pi_get_container)
    if [ -n "$container_name" ]; then
        ssh -i "$SSH_KEY" "$PI_USER@$PI_HOST" "docker exec $container_name bin/rails $rails_command" 2>&1
    else
        echo "No container found"
        return 1
    fi
}

pi_deploy() {
    # For Pi deployment, we need to use SSH to run kamal deploy from the Pi itself
    ssh -i "$SSH_KEY" "$PI_USER@$PI_HOST" "cd ~/routine && git pull && kamal deploy" 2>&1
}

# Check if host is reachable
check_host_reachable() {
    local host=$1
    log_info "Checking connectivity to $host..."
    
    if [ "$host" = "localhost" ]; then
        # For localhost, check if docker is running
        if ! command -v docker >/dev/null 2>&1; then
            log_error "Docker not found on localhost"
            return 1
        fi
        if ! docker info >/dev/null 2>&1; then
            log_error "Docker not running on localhost"
            return 1
        fi
        return 0
    elif [ "$host" = "$PI_HOST" ]; then
        # For Pi, check SSH connectivity
        if ! ping -c 1 -W 5 "$host" >/dev/null 2>&1; then
            log_error "Cannot ping $host"
            return 1
        fi
        if ! ssh -i "$SSH_KEY" -o ConnectTimeout=5 "$PI_USER@$host" "echo 'SSH OK'" >/dev/null 2>&1; then
            log_error "Cannot SSH to $host"
            return 1
        fi
        return 0
    else
        log_error "Unknown host: $host"
        return 1
    fi
}

# Check flag status on a deployment
check_flag_status() {
    local host=$1
    
    if [ "$host" = "localhost" ]; then
        # Check local deployment - try Docker first, fall back to Kamal
        local container_name=$(docker ps --format '{{.Names}}' | grep routine | head -1)
        
        if [ -n "$container_name" ]; then
            # App is running via Docker, check flag
            local flag_output
            flag_output=$(docker exec "$container_name" bin/rails flag:status 2>&1)
            if echo "$flag_output" | grep -q "Flag is PRESENT"; then
                echo "PRESENT"
            elif echo "$flag_output" | grep -q "Flag is MISSING"; then
                echo "MISSING"
            else
                echo "UNKNOWN"
            fi
        else
            # Try Kamal as fallback
            if kamal app logs -d local >/dev/null 2>&1; then
                # App is running via Kamal, check flag via Rails task
                local flag_output
                flag_output=$(kamal app exec -d local --reuse "bin/rails flag:status" 2>&1)
                if echo "$flag_output" | grep -q "Flag is PRESENT"; then
                    echo "PRESENT"
                elif echo "$flag_output" | grep -q "Flag is MISSING"; then
                    echo "MISSING"
                else
                    echo "UNKNOWN"
                fi
            else
                echo "OFFLINE"
            fi
        fi
    elif [ "$host" = "$PI_HOST" ]; then
        # Check Pi deployment via SSH using Docker directly (Pi doesn't have Kamal)
        local container_name
        container_name=$(ssh -i "$SSH_KEY" "$PI_USER@$host" "docker ps --format '{{.Names}}' | grep routine" 2>/dev/null | head -1)
        
        if [ -n "$container_name" ]; then
            # App is running, check flag
            local flag_output
            flag_output=$(pi_rails_exec "flag:status")
            if echo "$flag_output" | grep -q "Flag is PRESENT"; then
                echo "PRESENT"
            elif echo "$flag_output" | grep -q "Flag is MISSING"; then
                echo "MISSING"
            else
                echo "UNKNOWN"
            fi
        else
            echo "OFFLINE"
        fi
    fi
}

# Show status of both deployments
show_status() {
    echo "🏁 Flag Transfer System Status"
    echo "=================================================="
    echo
    
    # Check Pi status
    log_info "Raspberry Pi ($PI_HOST):"
    pi_status=$(check_flag_status "$PI_HOST")
    case $pi_status in
        "PRESENT") log_success "  Flag is PRESENT - This deployment is ACTIVE" ;;
        "MISSING") log_warning "  Flag is MISSING - This deployment is INACTIVE" ;;
        "OFFLINE") log_warning "  Deployment is OFFLINE or unreachable" ;;
        *) log_error "  Status UNKNOWN" ;;
    esac
    echo
    
    # Check laptop status  
    log_info "Laptop ($LAPTOP_HOST):"
    laptop_status=$(check_flag_status "$LAPTOP_HOST")
    case $laptop_status in
        "PRESENT") log_success "  Flag is PRESENT - This deployment is ACTIVE" ;;
        "MISSING") log_warning "  Flag is MISSING - This deployment is INACTIVE" ;;
        "OFFLINE") log_warning "  Deployment is OFFLINE or not deployed" ;;
        *) log_error "  Status UNKNOWN" ;;
    esac
    echo
    
    # Summary
    if [ "$pi_status" = "PRESENT" ] && [ "$laptop_status" = "PRESENT" ]; then
        log_error "⚠️  CONFLICT: Both deployments have the flag!"
        echo "   This should not happen. You may need to manually resolve this."
    elif [ "$pi_status" = "PRESENT" ]; then
        log_info "📍 Active deployment: Raspberry Pi ($PI_HOST)"
    elif [ "$laptop_status" = "PRESENT" ]; then
        log_info "📍 Active deployment: Laptop ($LAPTOP_HOST)"
    else
        log_warning "📍 No active deployment found"
        echo "   You may need to manually create a flag with: rails flag:force_create"
    fi
}

# Transfer flag between deployments
transfer_flag() {
    local target_host=$1
    local dry_run=${2:-false}
    
    log_info "Starting flag transfer to $target_host..."
    
    # Determine source and target
    local source_host
    if [ "$target_host" = "$LAPTOP_HOST" ]; then
        source_host="$PI_HOST"
    elif [ "$target_host" = "$PI_HOST" ]; then
        source_host="$LAPTOP_HOST"
    else
        log_error "Invalid target host: $target_host"
        exit 1
    fi
    
    log_info "Source: $source_host"
    log_info "Target: $target_host"
    echo
    
    # Check connectivity
    if ! check_host_reachable "$source_host"; then
        log_error "Cannot reach source host: $source_host"
        exit 1
    fi
    
    if ! check_host_reachable "$target_host"; then
        log_error "Cannot reach target host: $target_host"
        exit 1
    fi
    
    # Check current flag status
    source_flag=$(check_flag_status "$source_host")
    target_flag=$(check_flag_status "$target_host")
    
    log_info "Source flag status: $source_flag"
    log_info "Target flag status: $target_flag"
    echo
    
    # Validate transfer conditions
    if [ "$source_flag" != "PRESENT" ]; then
        log_error "Source ($source_host) does not have the flag!"
        echo "  Current source flag status: $source_flag"
        echo "  Cannot transfer a flag that doesn't exist."
        echo "  Run '$0 --status' to see current flag locations."
        exit 1
    fi
    
    if [ "$target_flag" = "PRESENT" ]; then
        log_error "Target ($target_host) already has the flag!"
        echo "  This would create a conflict."
        echo "  The flag is already where you're trying to transfer it."
        exit 1
    fi
    
    # Show what will happen
    echo "🔄 Transfer Plan:"
    echo "  1. Shutdown $source_host deployment"
    echo "  2. Export database from $source_host"
    echo "  3. Start/deploy $target_host (if needed)"
    echo "  4. Import database to $target_host"
    echo "  5. Remove flag from $source_host"
    echo "  6. Create flag on $target_host"
    echo "  7. Verify transfer success"
    echo
    
    if [ "$dry_run" = "true" ]; then
        log_info "DRY RUN MODE - No changes will be made"
        log_success "Transfer plan validated successfully"
        return 0
    fi
    
    # Confirmation
    log_warning "This will shutdown $source_host and transfer all data to $target_host"
    printf "Continue with flag transfer? (y/N): "
    read -r response
    
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_info "Transfer cancelled by user"
        exit 0
    fi
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    # Step 1: Shutdown source deployment
    log_info "Step 1: Shutting down $source_host deployment..."
    if [ "$source_host" = "$PI_HOST" ]; then
        pi_app_stop || log_warning "Source shutdown failed (may already be stopped)"
    else
        # For localhost, try Docker first, fall back to Kamal
        local container_name=$(docker ps --format '{{.Names}}' | grep routine | head -1)
        if [ -n "$container_name" ]; then
            docker stop "$container_name" || log_warning "Source shutdown failed (may already be stopped)"
        else
            kamal app stop -d local || log_warning "Source shutdown failed (may already be stopped)"
        fi
    fi
    log_success "Source deployment shutdown complete"
    
    # Step 2: Export database from source
    log_info "Step 2: Exporting database from $source_host..."
    export_file="$BACKUP_DIR/transfer_export_$TIMESTAMP.json"
    
    # Use helper script for database export
    if ! "./scripts/_export_database.sh" "$source_host" "$export_file"; then
        log_error "Failed to export database from $source_host"
        exit 1
    fi
    log_success "Database exported: $export_file"
    
    # Step 3: Deploy target if needed
    log_info "Step 3: Ensuring $target_host deployment is ready..."
    if [ "$target_host" = "$PI_HOST" ]; then
        pi_deploy || log_warning "Deploy may have failed"
    else
        # For localhost, try to deploy but don't fail if it has issues
        # We'll create a container manually if needed
        if ! timeout 60 kamal deploy -d local 2>/dev/null; then
            log_warning "Kamal deploy failed, will try to start existing container or create new one"
            # Try to start existing container if it exists
            local existing_container=$(docker ps -a --format '{{.Names}}' | grep routine | head -1)
            if [ -n "$existing_container" ]; then
                docker start "$existing_container" || log_warning "Failed to start existing container"
            else
                # If no container exists, try to pull and run a simple container for data import
                log_info "Creating temporary container for data import..."
                if docker pull josephburnett/routine:latest 2>/dev/null; then
                    docker run -d --name routine-local-temp \
                        -v survey_storage_local:/rails/storage \
                        -p 3000:3000 \
                        josephburnett/routine:latest || log_warning "Failed to create temporary container"
                else
                    log_warning "Could not pull routine image, import may fail"
                fi
            fi
        fi
    fi
    log_success "Target deployment ready"
    
    # Step 4: Import database to target
    log_info "Step 4: Importing database to $target_host..."
    
    # Use helper script for database import
    if ! "./scripts/_import_database.sh" "$target_host" "$export_file"; then
        log_error "Failed to import database to $target_host"
        log_warning "Attempting rollback to restore original state..."
        rollback_transfer "$source_host" "$target_host" "$export_file"
        exit 1
    fi
    log_success "Database imported to $target_host"
    
    # Step 5: Remove flag from source
    log_info "Step 5: Removing flag from $source_host..."
    if [ "$source_host" = "$PI_HOST" ]; then
        pi_rails_exec "flag:remove" >/dev/null || log_warning "Flag removal from source failed"
    else
        # For localhost, try Docker first, fall back to Kamal
        local container_name=$(docker ps --format '{{.Names}}' | grep routine | head -1)
        if [ -n "$container_name" ]; then
            docker exec "$container_name" bin/rails flag:remove >/dev/null || log_warning "Flag removal from source failed"
        else
            kamal app exec -d local --reuse "bin/rails flag:remove" >/dev/null || log_warning "Flag removal from source failed"
        fi
    fi
    log_success "Flag removed from $source_host"
    
    # Step 6: Create flag on target
    log_info "Step 6: Creating flag on $target_host..."
    if [ "$target_host" = "$PI_HOST" ]; then
        pi_rails_exec "flag:create[$source_host]" >/dev/null
    else
        # For localhost, try Docker first, fall back to Kamal
        local container_name=$(docker ps --format '{{.Names}}' | grep routine | head -1)
        if [ -n "$container_name" ]; then
            docker exec "$container_name" bin/rails flag:create[$source_host] >/dev/null
        else
            kamal app exec -d local --reuse "bin/rails flag:create[$source_host]" >/dev/null
        fi
    fi
    log_success "Flag created on $target_host"
    
    # Step 7: Verify transfer
    log_info "Step 7: Verifying transfer success..."
    sleep 5  # Give services time to settle
    
    final_source_flag=$(check_flag_status "$source_host")
    final_target_flag=$(check_flag_status "$target_host")
    
    if [ "$final_target_flag" = "PRESENT" ] && [ "$final_source_flag" != "PRESENT" ]; then
        log_success "🎉 Flag transfer completed successfully!"
        echo
        log_info "📍 Active deployment is now: $target_host"
        
        if [ "$target_host" = "$LAPTOP_HOST" ]; then
            echo "🌍 You can now access your app at: http://localhost:3000"
            echo "✈️  Have a great trip!"
        else
            echo "🏠 You can now access your app at: http://home.local:3000"
            echo "🏡 Welcome home!"
        fi
    else
        log_error "Transfer verification failed!"
        echo "  Target flag status: $final_target_flag"
        echo "  Source flag status: $final_source_flag"
        echo "  You may need to manually fix flag states."
    fi
    
    # Cleanup
    log_info "Cleaning up temporary files..."
    rm -f "$export_file"
}

# Main script logic
main() {
    case "${1:-}" in
        "--help"|"-h")
            show_help
            ;;
        "--status"|"-s")
            show_status
            ;;
        "--dry-run")
            if [ -z "${2:-}" ]; then
                log_error "Dry run requires a target host"
                echo "Usage: $0 --dry-run [localhost|home.local]"
                exit 1
            fi
            transfer_flag "$2" true
            ;;
        "localhost"|"home.local")
            transfer_flag "$1" false
            ;;
        "")
            log_error "Missing target host"
            echo "Usage: $0 [localhost|home.local|--status|--help]"
            exit 1
            ;;
        *)
            log_error "Invalid argument: $1"
            echo "Valid options: localhost, home.local, --status, --help"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"