# Flag Transfer System Guide

## Overview

The Flag Transfer System ensures only one deployment (Pi or laptop) runs at a time, preventing data conflicts when switching between locations. Think of it as "transferring your digital flag" between deployments.

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
./scripts/transfer_flag.sh home.local

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
./scripts/transfer_flag.sh home.local

# Verify transfer succeeded  
curl http://home.local:3000/up
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

## Flag Management Commands

### Via Transfer Script
```bash
./scripts/transfer_flag.sh --status    # Show flag status on both deployments
./scripts/transfer_flag.sh --help      # Full help and examples
```

### Via Rails Tasks (when app is running)
```bash
# On Pi
kamal app exec --reuse "bin/rails flag:status"
kamal app exec --reuse "bin/rails flag:create[source_info]"
kamal app exec --reuse "bin/rails flag:remove"

# On laptop  
kamal app exec -d local --reuse "bin/rails flag:status"
kamal app exec -d local --reuse "bin/rails flag:create[source_info]"
kamal app exec -d local --reuse "bin/rails flag:remove"
```

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
./scripts/transfer_flag.sh localhost    # Or home.local
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

# 3. Use backup file created during transfer
ls -la tmp/flag_transfer/  # Find the backup
# Then manually import using Rails tasks if needed
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

## Emergency Procedures

### Complete System Reset
If everything is broken and you need to start fresh:
```bash
# 1. Decide which deployment has the correct data
# 2. Force create flag there
kamal app exec --reuse "bin/rails flag:force_create[emergency_reset]"

# 3. Verify it works
curl http://home.local:3000/up    # or localhost:3000

# 4. Transfer normally to other deployment when ready
./scripts/transfer_flag.sh [target]
```

### Manual Database Copy
If the transfer system is completely broken:
```bash
# Export database manually
kamal app exec --reuse "bin/rails db:sync:export"

# Find and download export file
# (see DATABASE_SYNC.md for manual procedures)

# Import on target
kamal app exec -d local --reuse "bin/rails db:sync:import[/path/to/export.json]"
```

## Best Practices

1. **Always check status first** - Know where your flag is
2. **Use dry-run mode** - Preview transfers when uncertain  
3. **Don't force flags** - Use proper transfer process
4. **Keep backups** - Transfer files are preserved for recovery
5. **One direction at a time** - Don't make changes on both deployments
6. **Test connectivity** - Ensure you can reach target before transferring

The flag system prevents the exact scenario you were worried about - accidentally overwriting newer travel data with older home data. The flag always follows your data!