# Flag Transfer System

The Flag Transfer System ensures only one deployment (Pi or laptop) runs at a time, preventing data conflicts when switching between locations. Think of it as "transferring your digital flag" between deployments.

# Part 1: User Guide

## Core Concept

- **The Flag** = A simple file (`storage/ACTIVE_FLAG`) that represents the authoritative database
- **Only one deployment can hold the flag at a time**
- **Applications won't start without the flag** (prevents accidents)
- **Transfers are atomic** = shutdown source → copy data → transfer flag → start target

## Quick Commands

```bash
# Check where the flag currently is
./scripts/transfer_flag.sh --status

# Transfer flag to laptop (for travel)
./scripts/transfer_flag.sh localhost

# Transfer flag back to Pi (returning home)
./scripts/transfer_flag.sh home.taile52c2f.ts.net

# Preview what would happen (no changes made)
./scripts/transfer_flag.sh --dry-run localhost
```

## Travel Workflow

### 🧳 Before Leaving Home
```bash
# Check current status
./scripts/transfer_flag.sh --status

# Transfer to laptop for travel
./scripts/transfer_flag.sh localhost

# Verify transfer succeeded
curl http://localhost:3000/up
```

### ✈️ While Traveling
- Use your laptop deployment at `http://localhost:3000`
- Make changes, add data, etc. normally
- Your Pi deployment is safely shutdown with no flag

### 🏠 Returning Home
```bash
# Transfer back to Pi
./scripts/transfer_flag.sh home.taile52c2f.ts.net

# Verify transfer succeeded  
curl http://home.taile52c2f.ts.net:3000/up
```

## How It Works

### Transfer Process
1. **Validate** - Check source has flag, target doesn't
2. **Shutdown** - Stop source deployment safely
3. **Export** - Create JSON backup of all database tables
4. **Deploy** - Ensure target deployment is ready
5. **Import** - Load data into target deployment
6. **Flag Transfer** - Remove from source, create on target
7. **Verify** - Confirm transfer succeeded

### Safety Features
- **Confirmation prompts** before destructive operations
- **Dry run mode** to preview changes
- **Automatic rollback** if import fails
- **Backup preservation** - export files kept for recovery
- **Health checks** before and after transfer
- **Idempotent** - can resume from any failed step

## Troubleshooting

### "Both deployments have the flag"
This shouldn't happen but can occur if a transfer fails partially:
```bash
# Check status to see the conflict
./scripts/transfer_flag.sh --status

# Remove flag from the deployment that shouldn't have it
kamal app exec --reuse "bin/rails flag:remove"           # Pi
kamal app exec -d local --reuse "bin/rails flag:remove"  # Laptop
```

### "No deployments have the flag"
If no deployment has the flag (system is "broken"):
```bash
# Force create flag on the deployment with the correct data
kamal app exec --reuse "bin/rails flag:force_create[emergency_restore]"      # Pi
kamal app exec -d local --reuse "bin/rails flag:force_create[emergency_restore]"  # Laptop
```

### "Application won't start - missing flag"
This is the safety system working correctly:
```bash
# Don't bypass this - instead transfer the flag properly
./scripts/transfer_flag.sh localhost    # Or home.taile52c2f.ts.net
```

### Transfer fails midway
The script includes automatic rollback, but if that fails:
```bash
# Check what state things are in
./scripts/transfer_flag.sh --status

# Manual recovery options:
# 1. Restart original deployment
kamal app start                     # Pi
kamal app start -d local           # Laptop

# 2. Force create flag on working deployment
kamal app exec --reuse "bin/rails flag:force_create[manual_recovery]"
```

## Understanding Flag Status

When you run `./scripts/transfer_flag.sh --status`:

### Normal States
- **Pi: PRESENT**, Laptop: MISSING = Pi is active (normal home state)
- **Pi: MISSING**, Laptop: PRESENT = Laptop is active (normal travel state)

### Problem States  
- **Both: PRESENT** = Conflict! Both think they're active
- **Both: MISSING** = No active deployment (system broken)
- **Either: OFFLINE** = Deployment not running or unreachable

## Best Practices

1. **Always check status first** - Know where your flag is
2. **Use dry-run mode** - Preview transfers when uncertain  
3. **Don't force flags** - Use proper transfer process
4. **Keep backups** - Transfer files are preserved for recovery
5. **One direction at a time** - Don't make changes on both deployments
6. **Test connectivity** - Ensure you can reach target before transferring

# Part 2: Implementation Details

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

## Flag Validation Logic

The Rails initializer in `config/initializers/active_flag_check.rb` enforces the flag requirement:

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

## Docker vs Kamal Command Translation

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
ssh -i ~/.ssh/home.taile52c2f.ts.net joe@home.taile52c2f.ts.net "docker ps | grep routine"

# Test Rails command directly
ssh -i ~/.ssh/home.taile52c2f.ts.net joe@home.taile52c2f.ts.net \
    "docker exec CONTAINER_NAME bin/rails flag:status"

# Test grep pattern
echo "✅ Flag is PRESENT" | grep -q "Flag is PRESENT" && echo "MATCH"
```

**Common Fixes**:
- Remove `log_info` calls from inside `check_flag_status()` function
- Ensure function only outputs final status (PRESENT/MISSING/OFFLINE)
- Fix SSH key permissions: `chmod 600 ~/.ssh/home.taile52c2f.ts.net`

### 2. "kamal: command not found" Errors

**Symptoms**: Transfer fails with "bash: line 1: kamal: command not found"

**Root Cause**: Scripts trying to run Kamal commands on Pi via SSH, but Pi doesn't have Kamal installed.

**Fix**: Update scripts to use Docker commands directly.

### 3. Flag Validation Prevents Deployment

**Symptoms**: New deployment fails with "MISSING ACTIVE FLAG" error

**Solutions**:

Option A - Bootstrap existing deployment:
```bash
./scripts/bootstrap_flag_on_pi.sh
```

Option B - Force create flag:
```bash
kamal app exec --reuse "bin/rails flag:force_create['Bootstrap reason']"
```

### 4. Database Export/Import Failures

**Debug Export**:
```bash
# Test export manually
ssh -i ~/.ssh/home.taile52c2f.ts.net joe@home.taile52c2f.ts.net \
    "docker exec CONTAINER_NAME bin/rails db:sync:export"

# Check export file location
ssh -i ~/.ssh/home.taile52c2f.ts.net joe@home.taile52c2f.ts.net \
    "ls -la ~/routine/tmp/db_sync/"
```

**Debug Import**:
```bash
# Test import manually
kamal app exec -d local --reuse "bin/rails db:sync:import[/path/to/export.json]"
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
- Pi accessible at `home.taile52c2f.ts.net` from laptop
- SSH connectivity on standard port
- Sufficient bandwidth for database transfer

## Deployment Configuration

The system uses two separate deployment configurations:

- `config/deploy.yml` - Default configuration for Raspberry Pi deployment
- `config/deploy.local.yml` - Local laptop deployment configuration

Key differences:

| Aspect | Pi Deployment | Local Deployment |
|--------|---------------|------------------|
| Host | home.taile52c2f.ts.net | localhost |
| Architecture | ARM v7 | AMD64 |
| SSH User | joe | current user |
| SSH Key | ~/.ssh/home.taile52c2f.ts.net | default |
| Volume | survey_storage | survey_storage_local |

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

### Manual Database Copy
If the transfer system is completely broken:
```bash
# Export database manually
kamal app exec --reuse "bin/rails db:sync:export"

# Import on target
kamal app exec -d local --reuse "bin/rails db:sync:import[/path/to/export.json]"
```

## Security Considerations

- **SSH Keys**: Private key `~/.ssh/home.taile52c2f.ts.net` must have correct permissions (600)
- **Flag Authority**: Flag file grants deployment authorization - protect access
- **Database Transfer**: Export files contain full database - clean up after transfer
- **Container Access**: Direct Docker commands bypass Kamal security features

## Files and Locations

### Flag File
- **Location**: `storage/ACTIVE_FLAG` in each deployment
- **Content**: Creation timestamp, host info, transfer ID
- **Purpose**: Authorizes deployment to start

### Transfer Files
- **Backups**: `tmp/flag_transfer/transfer_export_YYYYMMDD_HHMMSS.json`
- **Logs**: Script output shows full transfer process
- **Helpers**: `scripts/_export_database.sh`, `scripts/_import_database.sh`

### Application Check
- **File**: `config/initializers/active_flag_check.rb`
- **Behavior**: Refuses to start in production without flag
- **Development**: Shows warning but allows startup