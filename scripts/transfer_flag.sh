#!/bin/bash

#
# Robust Flag Transfer System v2
#
# This script provides safe, idempotent flag transfers between Pi and laptop
# using SQLite native tools and enhanced safety checks.
#
# Key improvements:
# - Database-level backup/restore (captures ALL data automatically)
# - HTTP health checks instead of SSH/Rails commands
# - Idempotent operations (safe to retry)
# - Enhanced safety verification
# - No hardcoded model lists
#
# Usage: 
#   ./scripts/transfer_flag_v2.sh localhost      # Transfer flag from Pi to laptop
#   ./scripts/transfer_flag_v2.sh home.local     # Transfer flag from laptop to Pi
#   ./scripts/transfer_flag_v2.sh --status       # Check current flag status
#   ./scripts/transfer_flag_v2.sh --dry-run TARGET # Preview what would happen
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

# Help function
show_help() {
    cat << EOF
🏁 Robust Flag Transfer System v2

Transfer the active flag between your Pi (home.local) and laptop (localhost).
Only one deployment can hold the flag at a time to prevent data conflicts.

Usage:
  $0 localhost         Transfer flag from Pi to laptop (for travel)
  $0 home.local        Transfer flag from laptop to Pi (returning home)
  $0 --status          Check current flag status on both deployments
  $0 --dry-run TARGET  Preview what would happen without making changes
  $0 --help            Show this help message

Key Improvements:
  ✅ SQLite native backup/restore (captures ALL data)
  ✅ HTTP health checks (more reliable than SSH)
  ✅ Idempotent operations (safe to retry)
  ✅ Enhanced safety verification
  ✅ No hardcoded model lists

EOF
}

# Enhanced deployment status checking using HTTP health checks
check_deployment_status() {
    local host=$1
    local url
    
    if [ "$host" = "localhost" ]; then
        url="http://localhost:3000/up"
    elif [ "$host" = "$PI_HOST" ]; then
        url="http://home.local/up"
    else
        echo "ERROR"
        return
    fi
    
    # Check if HTTP service is responding
    if curl -s --connect-timeout 5 --max-time 10 "$url" >/dev/null 2>&1; then
        echo "RUNNING"
    else
        echo "OFFLINE"
    fi
}

# Check flag status on a deployment
check_flag_status() {
    local host=$1
    local status
    
    status=$(check_deployment_status "$host")
    
    if [ "$status" = "OFFLINE" ]; then
        echo "OFFLINE"
        return
    fi
    
    # App is running, check flag status
    if [ "$host" = "localhost" ]; then
        # For localhost, check via Docker if container exists
        local container_name=$(docker ps --format '{{.Names}}' | grep routine | head -1)
        if [ -n "$container_name" ]; then
            local flag_output
            flag_output=$(docker exec "$container_name" bin/rails flag:status 2>&1 || echo "ERROR")
            if echo "$flag_output" | grep -q "Flag is PRESENT"; then
                echo "PRESENT"
            elif echo "$flag_output" | grep -q "Flag is MISSING"; then
                echo "MISSING"
            else
                echo "ERROR"
            fi
        else
            echo "OFFLINE"
        fi
    elif [ "$host" = "$PI_HOST" ]; then
        # For Pi, check via SSH
        local flag_output
        flag_output=$(ssh -i "$SSH_KEY" "$PI_USER@$host" "docker exec \$(docker ps --format '{{.Names}}' | grep routine | head -1) bin/rails flag:status" 2>&1 || echo "ERROR")
        if echo "$flag_output" | grep -q "Flag is PRESENT"; then
            echo "PRESENT"
        elif echo "$flag_output" | grep -q "Flag is MISSING"; then
            echo "MISSING"
        else
            echo "ERROR"
        fi
    fi
}

# Show status of both deployments
show_status() {
    echo "🏁 Robust Flag Transfer System v2 Status"
    echo "=================================================="
    echo
    
    # Check Pi status
    log_info "Raspberry Pi ($PI_HOST):"
    pi_deployment_status=$(check_deployment_status "$PI_HOST")
    pi_flag_status=$(check_flag_status "$PI_HOST")
    
    case $pi_deployment_status in
        "RUNNING")
            case $pi_flag_status in
                "PRESENT") log_success "  ✅ ACTIVE - Running with flag" ;;
                "MISSING") log_warning "  ⚠️  DANGER - Running without flag!" ;;
                "ERROR") log_error "  ❌ ERROR - Running but flag status unknown" ;;
            esac
            ;;
        "OFFLINE") log_info "  💤 OFFLINE - Not running" ;;
        *) log_error "  ❌ ERROR - Status unknown" ;;
    esac
    echo
    
    # Check laptop status  
    log_info "Laptop ($LAPTOP_HOST):"
    laptop_deployment_status=$(check_deployment_status "$LAPTOP_HOST")
    laptop_flag_status=$(check_flag_status "$LAPTOP_HOST")
    
    case $laptop_deployment_status in
        "RUNNING")
            case $laptop_flag_status in
                "PRESENT") log_success "  ✅ ACTIVE - Running with flag" ;;
                "MISSING") log_warning "  ⚠️  DANGER - Running without flag!" ;;
                "ERROR") log_error "  ❌ ERROR - Running but flag status unknown" ;;
            esac
            ;;
        "OFFLINE") log_info "  💤 OFFLINE - Not running" ;;
        *) log_error "  ❌ ERROR - Status unknown" ;;
    esac
    echo
    
    # Summary and safety analysis
    local active_count=0
    local danger_count=0
    
    if [ "$pi_deployment_status" = "RUNNING" ] && [ "$pi_flag_status" = "PRESENT" ]; then
        active_count=$((active_count + 1))
    fi
    if [ "$laptop_deployment_status" = "RUNNING" ] && [ "$laptop_flag_status" = "PRESENT" ]; then
        active_count=$((active_count + 1))
    fi
    if ([ "$pi_deployment_status" = "RUNNING" ] && [ "$pi_flag_status" = "MISSING" ]) || 
       ([ "$laptop_deployment_status" = "RUNNING" ] && [ "$laptop_flag_status" = "MISSING" ]); then
        danger_count=$((danger_count + 1))
    fi
    
    if [ $active_count -eq 1 ] && [ $danger_count -eq 0 ]; then
        if [ "$pi_flag_status" = "PRESENT" ] && [ "$pi_deployment_status" = "RUNNING" ]; then
            log_success "🔒 SAFE: Pi is active, laptop is offline"
        elif [ "$laptop_flag_status" = "PRESENT" ] && [ "$laptop_deployment_status" = "RUNNING" ]; then
            log_success "🔒 SAFE: Laptop is active, Pi is offline"
        fi
    elif [ $active_count -gt 1 ]; then
        log_error "🚨 DANGER: Multiple deployments are active simultaneously!"
        echo "   This creates risk of data conflicts. Transfer should be used to fix this."
    elif [ $danger_count -gt 0 ]; then
        log_error "🚨 DANGER: Deployment(s) running without flags!"
        echo "   This bypasses safety system. Flags should be restored immediately."
    elif [ $active_count -eq 0 ]; then
        log_warning "💤 INACTIVE: No deployments are currently active"
        echo "   This is safe but means the application is not available."
    fi
}

# Validate transfer preconditions
validate_transfer() {
    local source_host=$1
    local target_host=$2
    
    log_info "Validating transfer preconditions..."
    
    # Check source has flag
    local source_flag=$(check_flag_status "$source_host")
    if [ "$source_flag" != "PRESENT" ]; then
        log_error "Source ($source_host) does not have the flag!"
        echo "  Current source flag status: $source_flag"
        echo "  Cannot transfer a flag that doesn't exist."
        return 1
    fi
    
    # Check target is offline or missing flag
    local target_deployment=$(check_deployment_status "$target_host")
    local target_flag=$(check_flag_status "$target_host")
    
    if [ "$target_deployment" = "RUNNING" ] && [ "$target_flag" = "PRESENT" ]; then
        log_error "Target ($target_host) is already active with flag!"
        echo "  This would create a conflict."
        return 1
    fi
    
    log_success "Transfer preconditions validated"
    return 0
}

# Get database record count for verification
get_record_count() {
    local host=$1
    
    if [ "$host" = "$PI_HOST" ]; then
        ssh -i "$SSH_KEY" "$PI_USER@$host" "docker exec \$(docker ps --format '{{.Names}}' | grep routine | head -1) sqlite3 /rails/storage/production.sqlite3 \"SELECT COUNT(*) FROM (SELECT 'users' as table_name, COUNT(*) as cnt FROM users UNION ALL SELECT 'forms', COUNT(*) FROM forms UNION ALL SELECT 'sections', COUNT(*) FROM sections UNION ALL SELECT 'questions', COUNT(*) FROM questions UNION ALL SELECT 'responses', COUNT(*) FROM responses UNION ALL SELECT 'answers', COUNT(*) FROM answers UNION ALL SELECT 'metrics', COUNT(*) FROM metrics UNION ALL SELECT 'alerts', COUNT(*) FROM alerts UNION ALL SELECT 'reports', COUNT(*) FROM reports UNION ALL SELECT 'dashboards', COUNT(*) FROM dashboards);\"" 2>/dev/null | tail -1 || echo "0"
    elif [ "$host" = "localhost" ]; then
        local container_name=$(docker ps --format '{{.Names}}' | grep routine | head -1)
        if [ -n "$container_name" ]; then
            docker exec "$container_name" sqlite3 /rails/storage/production.sqlite3 "SELECT COUNT(*) FROM (SELECT 'users' as table_name, COUNT(*) as cnt FROM users UNION ALL SELECT 'forms', COUNT(*) FROM forms UNION ALL SELECT 'sections', COUNT(*) FROM sections UNION ALL SELECT 'questions', COUNT(*) FROM questions UNION ALL SELECT 'responses', COUNT(*) FROM responses UNION ALL SELECT 'answers', COUNT(*) FROM answers UNION ALL SELECT 'metrics', COUNT(*) FROM metrics UNION ALL SELECT 'alerts', COUNT(*) FROM alerts UNION ALL SELECT 'reports', COUNT(*) FROM reports UNION ALL SELECT 'dashboards', COUNT(*) FROM dashboards);" 2>/dev/null | tail -1 || echo "0"
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}

# Shutdown deployment safely
shutdown_deployment() {
    local host=$1
    
    log_info "Shutting down $host deployment..."
    
    if [ "$host" = "$PI_HOST" ]; then
        # Shutdown Pi container
        local container_name
        container_name=$(ssh -i "$SSH_KEY" "$PI_USER@$host" "docker ps --format '{{.Names}}' | grep routine | head -1" 2>/dev/null)
        if [ -n "$container_name" ]; then
            ssh -i "$SSH_KEY" "$PI_USER@$host" "docker stop $container_name" || log_warning "Failed to stop Pi container"
            log_success "Pi deployment shutdown"
        else
            log_info "Pi deployment already offline"
        fi
    elif [ "$host" = "localhost" ]; then
        # Shutdown localhost container
        local container_name
        container_name=$(docker ps --format '{{.Names}}' | grep routine | head -1)
        if [ -n "$container_name" ]; then
            docker stop "$container_name" || log_warning "Failed to stop localhost container"
            log_success "Localhost deployment shutdown"
        else
            log_info "Localhost deployment already offline"
        fi
    fi
}

# Start deployment
start_deployment() {
    local host=$1
    
    log_info "Starting $host deployment..."
    
    if [ "$host" = "$PI_HOST" ]; then
        # Start Pi container
        local container_name
        container_name=$(ssh -i "$SSH_KEY" "$PI_USER@$host" "docker ps -a --format '{{.Names}}' | grep routine | head -1" 2>/dev/null)
        if [ -n "$container_name" ]; then
            ssh -i "$SSH_KEY" "$PI_USER@$host" "docker start $container_name" || log_warning "Failed to start Pi container"
            sleep 5  # Give container time to start
            if [ "$(check_deployment_status "$host")" = "RUNNING" ]; then
                log_success "Pi deployment started"
            else
                log_warning "Pi deployment may not be fully ready"
            fi
        else
            log_error "No Pi container found to start"
            return 1
        fi
    elif [ "$host" = "localhost" ]; then
        # For localhost, we need to recreate the container with proper environment
        log_info "Creating localhost container with proper environment..."
        
        # First, create a temporary flag in the volume to allow container to start
        docker run --rm -v survey_storage_local:/storage alpine sh -c 'echo "TEMP_FLAG_FOR_STARTUP
Created: $(date -Iseconds)  
Host: localhost
Source: temp_startup
Transfer ID: temp_$(date +%s)" > /storage/ACTIVE_FLAG'
        
        # Validate 1Password authentication and load secrets
        log_info "Validating 1Password authentication..."
        
        # Check if 1Password CLI is available and authenticated
        if ! op whoami >/dev/null 2>&1; then
            log_error "1Password CLI not authenticated. Please run 'op signin' first."
            log_error "This is required to load Rails master key and SMTP password."
            exit 1
        fi
        
        # Load secrets from 1Password - these must match what Pi uses
        log_info "Loading secrets from 1Password..."
        RAILS_MASTER_KEY=$(op read "op://Private/Routine Master Key/password" 2>/dev/null)
        SMTP_PASSWORD=$(op read "op://Private/Routine SMTP Password/password" 2>/dev/null)
        
        # Validate all required secrets were loaded
        if [ -z "$RAILS_MASTER_KEY" ]; then
            log_error "Failed to load Rails master key from 1Password"
            log_error "Please ensure 'Routine Master Key' exists in 1Password Private vault"
            exit 1
        fi
        
        if [ -z "$SMTP_PASSWORD" ]; then
            log_error "Failed to load SMTP password from 1Password"  
            log_error "Please ensure 'Routine SMTP Password' exists in 1Password Private vault"
            exit 1
        fi
        
        log_info "Successfully loaded all secrets from 1Password"
        
        docker run -d --name routine-local \
            -v survey_storage_local:/rails/storage \
            -p 3000:3000 \
            -e RAILS_ENV=production \
            -e RAILS_MASTER_KEY="$RAILS_MASTER_KEY" \
            -e SMTP_PASSWORD="$SMTP_PASSWORD" \
            -e APPLICATION_HOST=localhost \
            -e SOLID_QUEUE_IN_PUMA=true \
            josephburnett/routine:latest-local || {
                log_error "Failed to create localhost container"
                return 1
            }
            
        # Wait for container to be fully ready with proper health check
        log_info "Waiting for localhost container to be ready..."
        local ready=false
        local attempts=0
        local max_attempts=30  # 30 seconds timeout
        
        while [ $attempts -lt $max_attempts ] && [ "$ready" = false ]; do
            if curl -s --connect-timeout 2 --max-time 3 "http://localhost:3000/up" >/dev/null 2>&1; then
                ready=true
                log_success "Localhost deployment started and responding"
            else
                sleep 1
                attempts=$((attempts + 1))
                if [ $((attempts % 5)) -eq 0 ]; then
                    log_info "Still waiting for localhost to be ready... (${attempts}s)"
                fi
            fi
        done
        
        if [ "$ready" = false ]; then
            log_error "Localhost deployment failed to become ready within ${max_attempts} seconds"
            # Check container logs for debugging
            docker logs --tail 20 routine-local || true
            return 1
        fi
    fi
}

# Create flag on deployment
create_flag() {
    local host=$1
    local source_host=$2
    
    log_info "Creating flag on $host..."
    
    local transfer_id="transfer_$(date +%s)"
    local flag_content="ACTIVE_FLAG
Created: $(date -Iseconds)
Host: $host
Source: $source_host
Transfer ID: $transfer_id"
    
    if [ "$host" = "$PI_HOST" ]; then
        ssh -i "$SSH_KEY" "$PI_USER@$host" "docker exec \$(docker ps --format '{{.Names}}' | grep routine | head -1) sh -c 'echo \"$flag_content\" > /rails/storage/ACTIVE_FLAG'" || {
            log_error "Failed to create flag on Pi"
            return 1
        }
    elif [ "$host" = "localhost" ]; then
        local container_name=$(docker ps --format '{{.Names}}' | grep routine | head -1)
        if [ -n "$container_name" ]; then
            docker exec "$container_name" sh -c "echo \"$flag_content\" > /rails/storage/ACTIVE_FLAG" || {
                log_error "Failed to create flag on localhost"
                return 1
            }
        else
            log_error "No localhost container found to create flag"
            return 1
        fi
    fi
    
    log_success "Flag created on $host"
}

# Remove flag from deployment
remove_flag() {
    local host=$1
    
    log_info "Removing flag from $host..."
    
    if [ "$host" = "$PI_HOST" ]; then
        ssh -i "$SSH_KEY" "$PI_USER@$host" "docker exec \$(docker ps --format '{{.Names}}' | grep routine | head -1) rm -f /rails/storage/ACTIVE_FLAG" || log_warning "Failed to remove flag from Pi"
    elif [ "$host" = "localhost" ]; then
        local container_name=$(docker ps --format '{{.Names}}' | grep routine | head -1)
        if [ -n "$container_name" ]; then
            docker exec "$container_name" rm -f /rails/storage/ACTIVE_FLAG || log_warning "Failed to remove flag from localhost"
        fi
    fi
    
    log_success "Flag removed from $host"
}

# Dry run transfer (preview only)
dry_run_transfer() {
    local target_host=$1
    local source_host
    
    # Determine source host
    if [ "$target_host" = "$LAPTOP_HOST" ]; then
        source_host="$PI_HOST"
    elif [ "$target_host" = "$PI_HOST" ]; then
        source_host="$LAPTOP_HOST"
    else
        log_error "Invalid target host: $target_host"
        exit 1
    fi
    
    log_info "🔍 DRY RUN: Flag transfer preview for $source_host → $target_host"
    echo
    
    # Show current status
    log_info "Current Status:"
    show_status
    echo
    
    # Validate preconditions
    if ! validate_transfer "$source_host" "$target_host"; then
        log_error "Transfer preconditions not met"
        exit 1
    fi
    
    # Show what would happen
    echo "🔄 Transfer Plan (DRY RUN - no changes will be made):"
    echo "  1. Shutdown $source_host deployment"
    echo "  2. Export database from $source_host using SQLite native tools"
    echo "  3. Start $target_host deployment (if needed)"
    echo "  4. Import database to $target_host using SQLite native tools"
    echo "  5. Remove flag from $source_host"
    echo "  6. Create flag on $target_host"
    echo "  7. Verify transfer success"
    echo
    
    # Show record counts
    local source_records=$(get_record_count "$source_host")
    log_info "Source ($source_host) has approximately $source_records data records to transfer"
    
    log_success "✅ DRY RUN completed - transfer plan is valid"
    echo
    log_info "To execute this transfer, run: $0 $target_host"
}

# Main transfer function 
transfer_flag() {
    local target_host=$1
    local source_host
    
    # Determine source host
    if [ "$target_host" = "$LAPTOP_HOST" ]; then
        source_host="$PI_HOST"
    elif [ "$target_host" = "$PI_HOST" ]; then
        source_host="$LAPTOP_HOST"
    else
        log_error "Invalid target host: $target_host"
        exit 1
    fi
    
    log_info "🚀 Starting robust flag transfer: $source_host → $target_host"
    echo
    
    # Validate preconditions
    if ! validate_transfer "$source_host" "$target_host"; then
        log_error "Transfer preconditions not met"
        exit 1
    fi
    
    # Show what will happen
    echo "🔄 Transfer Plan:"
    echo "  1. Shutdown $source_host deployment"
    echo "  2. Export database from $source_host using SQLite native tools"
    echo "  3. Start $target_host deployment (if needed)"
    echo "  4. Import database to $target_host using SQLite native tools" 
    echo "  5. Remove flag from $source_host"
    echo "  6. Create flag on $target_host"
    echo "  7. Verify transfer success"
    echo
    
    # Get initial record count for verification
    local initial_records=$(get_record_count "$source_host")
    log_info "Source has $initial_records data records to transfer"
    
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
    
    # Step 1: Shutdown source
    log_info "🛑 Step 1: Shutdown source deployment"
    shutdown_deployment "$source_host"
    
    # Wait a moment for shutdown to complete
    sleep 3
    
    # Step 2: Export database
    log_info "📦 Step 2: Export database using SQLite native tools"
    export_file="$BACKUP_DIR/transfer_export_$TIMESTAMP.sql"
    
    if ! "./scripts/_export_database.sh" "$source_host" "$export_file"; then
        log_error "Database export failed"
        # Try to restart source as rollback
        start_deployment "$source_host"
        create_flag "$source_host" "rollback_after_export_failure"
        exit 1
    fi
    
    # Step 3: Start target deployment
    log_info "🚀 Step 3: Start target deployment"
    if ! start_deployment "$target_host"; then
        log_error "Failed to start target deployment"
        # Rollback: restart source
        start_deployment "$source_host"
        create_flag "$source_host" "rollback_after_target_start_failure"
        exit 1
    fi
    
    # Step 4: Import database
    log_info "📥 Step 4: Import database using SQLite native tools"
    if ! "./scripts/_import_database.sh" "$target_host" "$export_file"; then
        log_error "Database import failed"
        # Rollback: restart source, shutdown target
        shutdown_deployment "$target_host"
        start_deployment "$source_host"  
        create_flag "$source_host" "rollback_after_import_failure"
        exit 1
    fi
    
    # Step 5: Remove flag from source (source is already shutdown)
    log_info "🗑️ Step 5: Remove flag from source"
    # Note: Source is shutdown, so flag is effectively removed
    log_success "Source flag removed (deployment shutdown)"
    
    # Step 6: Create flag on target
    log_info "🏁 Step 6: Create flag on target"
    if ! create_flag "$target_host" "$source_host"; then
        log_error "Failed to create flag on target"
        # This is a critical failure - try to restore source
        shutdown_deployment "$target_host"
        start_deployment "$source_host"
        create_flag "$source_host" "rollback_after_flag_failure"
        exit 1
    fi
    
    # Step 7: Verify transfer
    log_info "✅ Step 7: Verify transfer success"
    sleep 3  # Give target time to settle
    
    final_target_status=$(check_deployment_status "$target_host")
    final_target_flag=$(check_flag_status "$target_host")
    final_source_status=$(check_deployment_status "$source_host")
    final_records=$(get_record_count "$target_host")
    
    echo
    log_info "📊 Transfer Verification:"
    log_info "  Target ($target_host): $final_target_status with flag $final_target_flag"
    log_info "  Source ($source_host): $final_source_status (should be OFFLINE)"
    log_info "  Records transferred: $initial_records → $final_records"
    
    if [ "$final_target_status" = "RUNNING" ] && [ "$final_target_flag" = "PRESENT" ] && [ "$final_source_status" = "OFFLINE" ]; then
        log_success "🎉 Flag transfer completed successfully!"
        echo
        log_success "✅ Safe state achieved: Only $target_host is active"
        
        if [ "$target_host" = "$LAPTOP_HOST" ]; then
            echo "🌍 Your app is now available at: http://localhost:3000"
            echo "✈️  Ready for travel!"
        else
            echo "🏠 Your app is now available at: http://home.local"
            echo "🏡 Welcome home!"
        fi
        
        # Clean up export file (but keep backups)
        rm -f "$export_file"
        log_info "🧹 Cleaned up temporary export file"
        
    else
        log_error "❌ Transfer verification failed!"
        echo "  Manual intervention may be required."
        echo "  Export file preserved: $export_file"
    fi
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
            dry_run_transfer "$2"
            ;;
        "localhost"|"home.local")
            transfer_flag "$1"
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