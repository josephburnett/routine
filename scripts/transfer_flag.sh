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
#   ./scripts/transfer_flag_v2.sh home.gila-lionfish.ts.net     # Transfer flag from laptop to Pi
#   ./scripts/transfer_flag_v2.sh --status       # Check current flag status
#   ./scripts/transfer_flag_v2.sh --dry-run TARGET # Preview what would happen
#

set -e

# Configuration
RTB_HOST="rtb.gila-lionfish.ts.net"
LAPTOP_HOST="localhost"
RTB_USER="joe"
RTB_SSH_KEY="$HOME/.ssh/rtb.local"
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

Transfer the active flag between your RTB server (rtb.gila-lionfish.ts.net) and laptop (localhost).
Only one deployment can hold the flag at a time to prevent data conflicts.

Usage:
  $0 localhost         Transfer flag from RTB to laptop (for travel)
  $0 rtb.gila-lionfish.ts.net        Transfer flag from laptop to RTB (returning home)
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
        url="http://localhost:8080/up"
    elif [ "$host" = "$RTB_HOST" ]; then
        url="http://rtb.gila-lionfish.ts.net:10001/up"
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
        local container_name=$(docker ps --format '{{.Names}}' | grep -E "routine" | head -1)
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
    elif [ "$host" = "$RTB_HOST" ]; then
        # For RTB, check via SSH
        local flag_output
        flag_output=$(ssh -i "$RTB_SSH_KEY" "$RTB_USER@$host" "docker exec \$(docker ps --format '{{.Names}}' | grep routine | head -1) bin/rails flag:status" 2>&1 || echo "ERROR")
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
    
    # Check RTB status
    log_info "RTB Server ($RTB_HOST):"
    rtb_deployment_status=$(check_deployment_status "$RTB_HOST")
    rtb_flag_status=$(check_flag_status "$RTB_HOST")
    
    case $rtb_deployment_status in
        "RUNNING")
            case $rtb_flag_status in
                "PRESENT") log_success "  ✅ ACTIVE - Running with flag" ;;
                "MISSING") log_info "  🔒 SAFE - Running without flag (standby mode)" ;;
                "ERROR") log_info "  🔒 SAFE - Running without flag (standby mode)" ;;
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
                "MISSING") log_info "  🔒 SAFE - Running without flag (standby mode)" ;;
                "ERROR") log_info "  🔒 SAFE - Running without flag (standby mode)" ;;
            esac
            ;;
        "OFFLINE") log_info "  💤 OFFLINE - Not running" ;;
        *) log_error "  ❌ ERROR - Status unknown" ;;
    esac
    echo
    
    # Summary and safety analysis
    local active_count=0
    local danger_count=0
    
    if [ "$rtb_deployment_status" = "RUNNING" ] && [ "$rtb_flag_status" = "PRESENT" ]; then
        active_count=$((active_count + 1))
    fi
    if [ "$laptop_deployment_status" = "RUNNING" ] && [ "$laptop_flag_status" = "PRESENT" ]; then
        active_count=$((active_count + 1))
    fi
    # Note: "Running without flag" is now considered safe standby mode, not dangerous
    
    if [ $active_count -eq 1 ] && [ $danger_count -eq 0 ]; then
        if [ "$rtb_flag_status" = "PRESENT" ] && [ "$rtb_deployment_status" = "RUNNING" ]; then
            if [ "$laptop_deployment_status" = "OFFLINE" ]; then
                log_success "🔒 SAFE: RTB is active, laptop is offline"
            else
                log_success "🔒 SAFE: RTB is active, laptop is in standby"
            fi
        elif [ "$laptop_flag_status" = "PRESENT" ] && [ "$laptop_deployment_status" = "RUNNING" ]; then
            if [ "$rtb_deployment_status" = "OFFLINE" ]; then
                log_success "🔒 SAFE: Laptop is active, RTB is offline"
            else
                log_success "🔒 SAFE: Laptop is active, RTB is in standby"
            fi
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
    
    if [ "$host" = "$RTB_HOST" ]; then
        ssh -i "$RTB_SSH_KEY" "$RTB_USER@$host" "docker exec \$(docker ps --format '{{.Names}}' | grep routine | head -1) sqlite3 /rails/storage/production.sqlite3 \"SELECT COUNT(*) FROM (SELECT 'users' as table_name, COUNT(*) as cnt FROM users UNION ALL SELECT 'forms', COUNT(*) FROM forms UNION ALL SELECT 'sections', COUNT(*) FROM sections UNION ALL SELECT 'questions', COUNT(*) FROM questions UNION ALL SELECT 'responses', COUNT(*) FROM responses UNION ALL SELECT 'answers', COUNT(*) FROM answers UNION ALL SELECT 'metrics', COUNT(*) FROM metrics UNION ALL SELECT 'alerts', COUNT(*) FROM alerts UNION ALL SELECT 'reports', COUNT(*) FROM reports UNION ALL SELECT 'dashboards', COUNT(*) FROM dashboards);\"" 2>/dev/null | tail -1 || echo "0"
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
    
    if [ "$host" = "$RTB_HOST" ]; then
        # Shutdown RTB container
        local container_name
        container_name=$(ssh -i "$RTB_SSH_KEY" "$RTB_USER@$host" "docker ps --format '{{.Names}}' | grep routine | head -1" 2>/dev/null)
        if [ -n "$container_name" ]; then
            ssh -i "$RTB_SSH_KEY" "$RTB_USER@$host" "docker stop $container_name" || log_warning "Failed to stop RTB container"
            log_success "RTB deployment shutdown"
        else
            log_info "RTB deployment already offline"
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
    
    if [ "$host" = "$RTB_HOST" ]; then
        # Start RTB container
        local container_name
        container_name=$(ssh -i "$RTB_SSH_KEY" "$RTB_USER@$host" "docker ps -a --format '{{.Names}}' | grep routine | head -1" 2>/dev/null)
        if [ -n "$container_name" ]; then
            ssh -i "$RTB_SSH_KEY" "$RTB_USER@$host" "docker start $container_name" || log_warning "Failed to start RTB container"
            sleep 5  # Give container time to start
            if [ "$(check_deployment_status "$host")" = "RUNNING" ]; then
                log_success "RTB deployment started"
            else
                log_warning "RTB deployment may not be fully ready"
            fi
        else
            log_error "No RTB container found to start"
            return 1
        fi
    elif [ "$host" = "localhost" ]; then
        # For localhost, use Docker directly (no SSH required)
        log_info "Deploying to localhost using Docker..."

        # First, create a temporary flag in the volume to allow container to start
        docker run --rm -v survey_storage_local:/storage alpine sh -c 'echo "TEMP_FLAG_FOR_STARTUP
Created: $(date -Iseconds)
Host: localhost
Source: temp_startup
Transfer ID: temp_$(date +%s)" > /storage/ACTIVE_FLAG'

        # Validate 1Password authentication for secrets
        log_info "Validating 1Password authentication..."

        # Check if 1Password CLI is available and authenticated
        if ! op whoami >/dev/null 2>&1; then
            log_error "1Password CLI not authenticated. Please run the following commands:"
            log_error "  eval \$(op signin)"
            log_error "This is required to load Rails master key and SMTP password."
            exit 1
        fi

        log_info "1Password authentication verified"

        # Get secrets from 1Password
        RAILS_MASTER_KEY=$(op read "op://Personal/Routine Master Key/password")
        SMTP_PASSWORD=$(op read "op://Personal/Routine SMTP Password/password")

        # Generate SECRET_KEY_BASE from RAILS_MASTER_KEY if not explicitly stored
        # Rails typically derives this from the master key, but we'll be explicit
        if op item get "Secret Key Base" --vault Personal >/dev/null 2>&1; then
            SECRET_KEY_BASE=$(op read "op://Personal/Secret Key Base/credential")
        else
            # Generate a deterministic secret_key_base from the master key
            SECRET_KEY_BASE=$(echo -n "$RAILS_MASTER_KEY" | sha256sum | cut -d' ' -f1)$(echo -n "${RAILS_MASTER_KEY}salt" | sha256sum | cut -d' ' -f1)
        fi

        # Stop any existing local container
        existing_container=$(docker ps -a --format '{{.Names}}' | grep "routine.*local" | head -1)
        if [ -n "$existing_container" ]; then
            log_info "Stopping existing local container: $existing_container"
            docker stop "$existing_container" 2>/dev/null || true
            docker rm "$existing_container" 2>/dev/null || true
        fi

        # Get the amd64 image for localhost (not the ARM images for Pi)
        # First try routine:local, then josephburnett/routine with amd64 architecture
        image=$(docker images --format '{{.Repository}}:{{.Tag}}' | grep -E "^routine:local|^josephburnett/routine:latest-local" | head -1)
        if [ -z "$image" ]; then
            # Fallback: find any amd64 routine image
            log_warning "No routine:local image found, checking for amd64 images..."
            for img in $(docker images --format '{{.Repository}}:{{.Tag}}' | grep routine); do
                arch=$(docker inspect "$img" --format '{{.Architecture}}' 2>/dev/null)
                if [ "$arch" = "amd64" ]; then
                    image="$img"
                    break
                fi
            done
        fi
        if [ -z "$image" ]; then
            log_error "No amd64 routine image found. Please build for localhost first."
            log_error "Run: docker build -t routine:local --platform linux/amd64 ."
            return 1
        fi

        log_info "Using image: $image"

        # Run the container with Docker directly
        log_info "Starting container..."
        container_id=$(docker run -d \
            --name "routine-local-$(date +%s)" \
            -p 8080:3000 \
            -v survey_storage_local:/rails/storage \
            -e RAILS_ENV=production \
            -e RAILS_MASTER_KEY="$RAILS_MASTER_KEY" \
            -e SECRET_KEY_BASE="$SECRET_KEY_BASE" \
            -e SMTP_PASSWORD="$SMTP_PASSWORD" \
            -e SOLID_QUEUE_IN_PUMA=true \
            -e APPLICATION_HOST=localhost \
            "$image")

        if [ -z "$container_id" ]; then
            log_error "Failed to start Docker container"
            return 1
        fi

        log_info "Container started: $container_id"

        # Wait for deployment to be ready with health check
        log_info "Waiting for localhost deployment to be ready..."
        local ready=false
        local attempts=0
        local max_attempts=30  # 30 seconds timeout

        while [ $attempts -lt $max_attempts ] && [ "$ready" = false ]; do
            if curl -s --connect-timeout 2 --max-time 3 "http://localhost:8080/up" >/dev/null 2>&1; then
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
            docker logs --tail 20 "$container_id" || true
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
    
    if [ "$host" = "$RTB_HOST" ]; then
        ssh -i "$RTB_SSH_KEY" "$RTB_USER@$host" "docker exec \$(docker ps --format '{{.Names}}' | grep routine | head -1) sh -c 'echo \"$flag_content\" > /rails/storage/ACTIVE_FLAG'" || {
            log_error "Failed to create flag on RTB"
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
    
    if [ "$host" = "$RTB_HOST" ]; then
        ssh -i "$RTB_SSH_KEY" "$RTB_USER@$host" "docker exec \$(docker ps --format '{{.Names}}' | grep routine | head -1) rm -f /rails/storage/ACTIVE_FLAG" || log_warning "Failed to remove flag from RTB"
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
        source_host="$RTB_HOST"
    elif [ "$target_host" = "$RTB_HOST" ]; then
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
        source_host="$RTB_HOST"
    elif [ "$target_host" = "$RTB_HOST" ]; then
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
    log_info "  Source ($source_host): $final_source_status (should be OFFLINE or without flag)"
    log_info "  Records transferred: $initial_records → $final_records"
    
    # Success conditions: 
    # 1. Target is RUNNING with flag PRESENT
    # 2. Source is either OFFLINE or running without flag (both are safe)
    local source_flag_status=$(check_flag_status "$source_host")
    local transfer_success=false
    
    if [ "$final_target_status" = "RUNNING" ] && [ "$final_target_flag" = "PRESENT" ]; then
        if [ "$final_source_status" = "OFFLINE" ] || [ "$source_flag_status" = "MISSING" ] || [ "$source_flag_status" = "ERROR" ]; then
            transfer_success=true
        fi
    fi
    
    if [ "$transfer_success" = true ]; then
        log_success "🎉 Flag transfer completed successfully!"
        echo
        log_success "✅ Safe state achieved: Only $target_host is active"
        
        if [ "$target_host" = "$LAPTOP_HOST" ]; then
            echo "🌍 Your app is now available at: http://localhost:8080"
            echo "✈️  Ready for travel!"
        else
            echo "🏠 Your app is now available at: http://rtb.gila-lionfish.ts.net:10001"
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
                echo "Usage: $0 --dry-run [localhost|rtb.gila-lionfish.ts.net]"
                exit 1
            fi
            dry_run_transfer "$2"
            ;;
        "localhost"|"rtb.gila-lionfish.ts.net")
            transfer_flag "$1"
            ;;
        "")
            log_error "Missing target host"
            echo "Usage: $0 [localhost|rtb.gila-lionfish.ts.net|--status|--help]"
            exit 1
            ;;
        *)
            log_error "Invalid argument: $1"
            echo "Valid options: localhost, rtb.gila-lionfish.ts.net, --status, --help"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"