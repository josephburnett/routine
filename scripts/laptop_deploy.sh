#!/bin/bash

#
# Laptop Deploy Script
#
# This script helps deploy code changes while traveling on your laptop.
# It builds and deploys new code to your local laptop deployment.
#
# Usage: ./scripts/laptop_deploy.sh
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
🚀 Laptop Deploy Script

This script builds and deploys your code changes to the laptop while traveling.
It works with the flag transfer system to maintain data consistency.

Usage:
  $0                    Build and deploy code changes
  $0 --build-only       Build image but don't deploy
  $0 --deploy-only      Deploy without building (use existing image)
  $0 --status           Show current deployment status
  $0 --help             Show this help message

Requirements:
- Must be logged into 1Password (eval \$(op signin))
- Laptop should have the active flag (be the active deployment)
- Docker must be running

The script will:
1. Check if laptop should be active (safety check)
2. Build new Docker image from current code
3. Deploy using Kamal
4. Verify deployment is working
5. Run tests if available

EOF
}

# Check if laptop should be active
check_laptop_active() {
    if ! docker run --rm -v survey_storage_local:/storage alpine test -f /storage/ACTIVE_FLAG 2>/dev/null; then
        log_error "Laptop does not have the active flag!"
        log_error "You can only deploy code changes when laptop is the active deployment."
        log_error "Run './scripts/transfer_flag.sh localhost' to make laptop active first."
        return 1
    fi
    return 0
}

# Check if 1Password is authenticated
check_1password() {
    if ! op whoami >/dev/null 2>&1; then
        log_error "1Password CLI not authenticated. Please run:"
        log_error "  eval \$(op signin)"
        return 1
    fi
    return 0
}

# Build new image
build_image() {
    log_info "Building new Docker image from current code..."
    
    if kamal build -d local; then
        log_success "Image built successfully"
        return 0
    else
        log_error "Image build failed"
        return 1
    fi
}

# Deploy the application
deploy_app() {
    log_info "Deploying to laptop using Kamal..."
    
    if kamal deploy -d local; then
        log_success "Deployment completed"
        
        # Wait for it to be ready
        log_info "Waiting for deployment to be ready..."
        local attempts=0
        local max_attempts=30
        
        while [ $attempts -lt $max_attempts ]; do
            if curl -s --connect-timeout 2 --max-time 3 "http://localhost:8080/up" >/dev/null 2>&1; then
                log_success "Deployment is running and responding"
                return 0
            fi
            sleep 1
            attempts=$((attempts + 1))
            if [ $((attempts % 5)) -eq 0 ]; then
                log_info "Still waiting... (${attempts}s)"
            fi
        done
        
        log_error "Deployment completed but not responding after ${max_attempts}s"
        log_info "Check logs with: kamal app logs -d local"
        return 1
    else
        log_error "Deployment failed"
        log_info "Check logs with: kamal app logs -d local"
        return 1
    fi
}

# Run tests if available
run_tests() {
    log_info "Running tests..."
    
    if [ -f "Gemfile" ] && bundle list | grep -q rspec 2>/dev/null; then
        if bundle exec rspec; then
            log_success "All tests passed"
        else
            log_warning "Some tests failed - but deployment is still running"
        fi
    elif [ -f "package.json" ] && grep -q "test" package.json; then
        if npm test; then
            log_success "All tests passed"
        else
            log_warning "Some tests failed - but deployment is still running"
        fi
    else
        # Try the project's test command
        if rake test 2>/dev/null; then
            log_success "All tests passed"
        else
            log_info "No tests found or test command failed"
        fi
    fi
}

# Show deployment status
show_status() {
    log_info "Current laptop deployment status:"
    echo
    
    # Check if active
    if docker run --rm -v survey_storage_local:/storage alpine test -f /storage/ACTIVE_FLAG 2>/dev/null; then
        log_success "Laptop has active flag"
    else
        log_warning "Laptop does not have active flag"
    fi
    
    # Check if running
    if curl -s --connect-timeout 2 --max-time 3 "http://localhost:8080/up" >/dev/null 2>&1; then
        log_success "Application is running and responding"
        echo "🌍 Available at: http://localhost:8080"
    else
        log_warning "Application is not responding"
    fi
    
    # Show container status
    echo
    log_info "Container status:"
    kamal app details -d local 2>/dev/null || {
        log_info "No Kamal deployment found, checking Docker directly:"
        docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep routine || log_info "No routine containers found"
    }
}

# Main function
main() {
    case "${1:-}" in
        "--help"|"-h")
            show_help
            exit 0
            ;;
        "--status")
            show_status
            exit 0
            ;;
        "--build-only")
            log_info "🔨 Building laptop deployment image..."
            check_1password || exit 1
            build_image || exit 1
            log_success "Build completed. Use --deploy-only to deploy."
            ;;
        "--deploy-only")
            log_info "🚀 Deploying to laptop..."
            check_1password || exit 1
            check_laptop_active || exit 1
            deploy_app || exit 1
            ;;
        "")
            log_info "🚀 Building and deploying code changes to laptop..."
            
            # Pre-flight checks
            check_1password || exit 1
            check_laptop_active || exit 1
            
            # Build and deploy
            build_image || exit 1
            deploy_app || exit 1
            
            # Post-deployment verification
            echo
            log_info "🧪 Running post-deployment tests..."
            run_tests
            
            echo
            log_success "🎉 Deployment completed successfully!"
            echo "🌍 Your app is available at: http://localhost:8080"
            echo "📱 Use './scripts/transfer_flag.sh --status' to check system status"
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