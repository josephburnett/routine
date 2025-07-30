# Flag Transfer System: Mechanics and Debugging Guide

## Overview

The flag transfer system ensures only one deployment (Pi or laptop) is active at a time, preventing data conflicts when traveling between home.local and localhost deployments. This document explains the internal mechanics and provides debugging procedures.

## System Architecture

### Core Components

1. **Active Flag File**: `/rails/storage/ACTIVE_FLAG` - A file that authorizes a deployment to run
2. **Flag Validation**: Rails initializer that checks for flag presence at startup
3. **Transfer Script**: Orchestrates atomic flag transfers between deployments
4. **Database Sync**: Exports/imports data during transfers
5. **Docker Integration**: Uses Docker commands directly for Pi operations

### File Structure

```
scripts/
├── transfer_flag.sh           # Main transfer orchestrator
├── _export_database.sh        # Database export helper (internal)
├── _import_database.sh        # Database import helper (internal)
├── bootstrap_flag_on_pi.sh    # Manual flag creation on existing Pi
└── bootstrap_flag_volume.sh   # Create flag directly in Docker volume

config/initializers/
└── active_flag_check.rb       # Runtime flag validation

lib/tasks/
└── flag.rake                  # Rails tasks for flag management
```

## Transfer Process Flow

### Atomic Transfer Steps

1. **Validation**: Check source has flag, target doesn't
2. **Shutdown**: Stop source deployment container
3. **Export**: Extract database from source deployment
4. **Deploy**: Ensure target deployment is running
5. **Import**: Load database into target deployment
6. **Flag Transfer**: Remove from source, create on target
7. **Verification**: Confirm transfer success

### Critical Success Factors

- **Atomicity**: Either all steps succeed or system rolls back
- **Data Integrity**: Database export/import must complete successfully
- **Flag Uniqueness**: Only one deployment can have the flag at any time
- **Container Management**: Proper Docker container lifecycle handling

## Technical Implementation Details

### Flag Validation Logic (active_flag_check.rb)

```ruby
# Skip during build contexts (assets:precompile, etc.)
if ENV['DOCKER_BUILDKIT'] == '1' || 
   ENV['BUILDX_BUILDER'] ||
   ENV.key?('BUILD_CONTEXT') ||
   ENV['SECRET_KEY_BASE_DUMMY'] == '1' ||
   !File.directory?(Rails.root.join('storage'))
  # Skip flag check - build context
else
  # Enforce flag requirement in runtime
  flag_file = Rails.root.join('storage', 'ACTIVE_FLAG')
  unless File.exist?(flag_file)
    raise MissingActiveFlagError, "Flag required but missing"
  end
end
```

### Docker vs Kamal Command Translation

**Problem**: Pi doesn't have Kamal installed locally, but transfer script runs commands via SSH.

**Solution**: Use Docker commands directly for Pi operations:

| Kamal Command | Docker Equivalent |
|---------------|------------------|
| `kamal app exec --reuse 'rails task'` | `docker exec $container bin/rails task` |
| `kamal app start` | `docker start $container` |
| `kamal app stop` | `docker stop $container` |
| `kamal app logs` | `docker logs $container` |

### Container Discovery Pattern

```bash
# Find routine container on Pi
pi_get_container() {
    ssh -i "$SSH_KEY" "$PI_USER@$PI_HOST" \
        "docker ps --format '{{.Names}}' | grep routine" 2>/dev/null | head -1
}

# Execute Rails command in container
pi_rails_exec() {
    local rails_command="$1"
    local container_name=$(pi_get_container)
    ssh -i "$SSH_KEY" "$PI_USER@$PI_HOST" \
        "docker exec $container_name bin/rails $rails_command"
}
```

## Common Issues and Debugging

### 1. "Status UNKNOWN" Issues

**Symptoms**: `./scripts/transfer_flag.sh --status` shows UNKNOWN for deployments

**Root Causes**:
- Function return value pollution from log output
- Grep pattern not matching Rails command output
- SSH/Docker command failures

**Debug Steps**:
```bash
# Test Pi connection
ssh -i ~/.ssh/home.local joe@home.local "docker ps | grep routine"

# Test Rails command directly
ssh -i ~/.ssh/home.local joe@home.local \
    "docker exec CONTAINER_NAME bin/rails flag:status"

# Test grep pattern
echo "✅ Flag is PRESENT" | grep -q "Flag is PRESENT" && echo "MATCH"
```

**Common Fixes**:
- Remove `log_info` calls from inside `check_flag_status()` function
- Ensure function only outputs final status (PRESENT/MISSING/OFFLINE)
- Fix SSH key permissions: `chmod 600 ~/.ssh/home.local`

### 2. "kamal: command not found" Errors

**Symptoms**: Transfer fails with "bash: line 1: kamal: command not found"

**Root Cause**: Scripts trying to run Kamal commands on Pi via SSH, but Pi doesn't have Kamal installed.

**Fix**: Update scripts to use Docker commands directly (see helper functions above).

**Files to Check**:
- `scripts/_export_database.sh`
- `scripts/_import_database.sh`
- `scripts/transfer_flag.sh`

### 3. Container Offline/Missing Issues

**Symptoms**: "Deployment is OFFLINE" when container should be running

**Debug Steps**:
```bash
# Check container status on Pi
ssh -i ~/.ssh/home.local joe@home.local "docker ps -a | grep routine"

# Start stopped container
ssh -i ~/.ssh/home.local joe@home.local \
    "docker start \$(docker ps -a --format '{{.Names}}' | grep routine | head -1)"

# Check container logs
ssh -i ~/.ssh/home.local joe@home.local \
    "docker logs \$(docker ps --format '{{.Names}}' | grep routine | head -1)"
```

### 4. Flag Validation Prevents Deployment

**Symptoms**: New deployment fails with "MISSING ACTIVE FLAG" error

**Solutions**:

Option A - Bootstrap existing deployment:
```bash
./scripts/bootstrap_flag_on_pi.sh
```

Option B - Temporarily disable validation:
```ruby
# In config/initializers/active_flag_check.rb
next if Rails.env.development? || ENV['SKIP_FLAG_CHECK'] == '1'
```

Option C - Force create flag:
```bash
kamal app exec --reuse "bin/rails flag:force_create['Bootstrap reason']"
```

### 5. Database Export/Import Failures

**Symptoms**: Transfer fails at export or import step

**Debug Export**:
```bash
# Test export manually
ssh -i ~/.ssh/home.local joe@home.local \
    "docker exec CONTAINER_NAME bin/rails db:sync:export"

# Check export file location
ssh -i ~/.ssh/home.local joe@home.local \
    "ls -la ~/routine/tmp/db_sync/"
```

**Debug Import**:
```bash
# Test import manually
kamal app exec -d local --reuse "bin/rails db:sync:import[/path/to/export.json]"
```

### 6. Transfer Script Bash Issues

**Common Bash Pitfalls**:

- **Glob Expansion**: `echo "=" * 50` expands to file listing
  - Fix: `echo "=================================================="`

- **Function Return Pollution**: Log output mixed with return values
  - Fix: Only echo final status, use `>&2` for debug output

- **SSH Quoting**: Complex commands need proper quoting
  - Fix: Use heredocs or escape quotes carefully

## Maintenance Commands

### Status and Diagnostics
```bash
# Check current flag status
./scripts/transfer_flag.sh --status

# Diagnose storage issues
./scripts/diagnose_storage.sh

# Manual flag status check
ssh -i ~/.ssh/home.local joe@home.local \
    "docker exec \$(docker ps --format '{{.Names}}' | grep routine | head -1) bin/rails flag:status"
```

### Manual Recovery
```bash
# Restart Pi container
ssh -i ~/.ssh/home.local joe@home.local \
    "docker start \$(docker ps -a --format '{{.Names}}' | grep routine | head -1)"

# Create flag manually
kamal app exec --reuse "bin/rails flag:create['manual']"

# Remove flag
kamal app exec --reuse "bin/rails flag:remove"
```

### Testing Transfer System
```bash
# Dry run transfer
./scripts/transfer_flag.sh --dry-run localhost

# Full transfer
./scripts/transfer_flag.sh localhost

# Transfer back
./scripts/transfer_flag.sh home.local
```

## Environment Requirements

### Pi Requirements
- Docker installed and running
- SSH access with key authentication
- No Kamal installation required (uses Docker directly)
- Volume persistence: `survey_storage` volume mounted to `/rails/storage`

### Laptop Requirements
- Kamal installed locally
- Docker installed and running
- Local deployment configuration in `config/deploy.local.yml`

### Network Requirements
- Pi accessible at `home.local` from laptop
- SSH connectivity on standard port
- Sufficient bandwidth for database transfer

## Security Considerations

- **SSH Keys**: Private key `~/.ssh/home.local` must have correct permissions (600)
- **Flag Authority**: Flag file grants deployment authorization - protect access
- **Database Transfer**: Export files contain full database - clean up after transfer
- **Container Access**: Direct Docker commands bypass Kamal security features

## Recovery Procedures

### Emergency Flag Creation
If both deployments lose the flag:
```bash
# On the deployment with the most recent data
kamal app exec --reuse "bin/rails flag:force_create['Emergency recovery']"
```

### Corrupt Transfer Recovery
If transfer fails mid-process:
1. Check which deployment has the flag: `./scripts/transfer_flag.sh --status`
2. If no flag exists, manually create on deployment with latest data
3. If both have flags, remove from older deployment
4. Verify data integrity on active deployment

### Database Corruption Recovery
If database import fails:
1. Export backup is preserved in `./tmp/flag_transfer/`
2. Manually restore using Rails console or database tools
3. Re-run transfer after confirming data integrity

This documentation should provide sufficient detail for future debugging and maintenance of the flag transfer system.