# Database Sync for Travel

This document explains how to synchronize your SQLite database between your Raspberry Pi at home and your laptop for travel use.

## Overview

The Routine Tracker uses SQLite databases that need to be manually synchronized when switching between your Pi (home.local) and laptop (localhost) deployments. This process involves:

1. **Before Travel**: Export data from Pi to laptop
2. **During Travel**: Use laptop deployment with copied data  
3. **After Travel**: Sync changes back from laptop to Pi

## Quick Reference

| When | Command | Purpose |
|------|---------|---------|
| Before leaving home | `./scripts/backup_pi_database.sh` | Get latest data from Pi |
| On laptop | `./scripts/restore_to_laptop.sh` | Import Pi data to laptop |
| After returning home | `./scripts/sync_back_to_pi.sh` | Sync laptop changes to Pi |

## Detailed Process

### 1. Before Leaving Home

Run this on your main machine (with access to home.local):

```bash
# Export the latest database from your Pi
./scripts/backup_pi_database.sh
```

This script will:
- Connect to your Pi via SSH
- Export all database tables to JSON format
- Download the export file to `./tmp/pi_backup/`
- Also backup the raw SQLite files as failsafe

**Files created:**
- `./tmp/pi_backup/db_export_YYYYMMDD_HHMMSS.json` - Main export file
- `./tmp/pi_backup/production*.sqlite3` - Raw SQLite backup files

### 2. On Your Laptop (Travel)

Copy the backup files to your laptop and run:

```bash
# Deploy the application locally
kamal deploy -d local

# Import the Pi database 
./scripts/restore_to_laptop.sh
```

The restore script will:
- Start local deployment if needed
- Import all data from the Pi export
- Clear existing local data first (if any)
- Verify the import completed successfully

**Access your app:** http://localhost:3000

### 3. After Returning Home

When you're back home and want to sync your travel changes to the Pi:

```bash
# Sync changes from laptop back to Pi
./scripts/sync_back_to_pi.sh
```

This script will:
- Export data from your laptop deployment
- Connect to your Pi
- Import the laptop data to Pi (replacing existing data)
- Clean up temporary files

## Manual Database Operations

### Emergency SQLite File Copy

If the scripts fail, you can manually copy SQLite files:

```bash
# Copy FROM Pi TO laptop
scp -i ~/.ssh/home.local joe@home.local:~/routine/storage/production*.sqlite3 ./storage/

# Copy FROM laptop TO Pi  
scp -i ~/.ssh/home.local ./storage/production*.sqlite3 joe@home.local:~/routine/storage/
```

### Check Database Status

```bash
# Check Pi database via Kamal
kamal dbc -d production
# Then: .tables, SELECT COUNT(*) FROM users;

# Check laptop database via Kamal  
kamal dbc -d local
# Then: .tables, SELECT COUNT(*) FROM users;
```

## Important Notes

### Data Loss Prevention
- **Always backup before syncing** - The sync process replaces all data
- **Test your backups** - Verify imports work before relying on them
- **One-way sync** - Each sync completely replaces the target database

### Network Requirements
- **Pi backup/sync**: Requires access to home.local (home network or VPN)
- **Laptop deployment**: Works offline after initial deployment
- **Docker registry**: Requires internet for image pulls

### Conflict Resolution
- **No automatic merging** - Last sync wins
- **Manual resolution needed** - If you make changes on both devices
- **Consider timing** - Sync before and after travel periods

## Troubleshooting

### Common Issues

**"Cannot reach Pi at home.local"**
```bash
# Check network connectivity
ping home.local

# Test SSH access
ssh -i ~/.ssh/home.local joe@home.local
```

**"Local deployment not running"**
```bash
# Start local deployment
kamal deploy -d local

# Check status
kamal app logs -d local
```

**"Export file not found"**
```bash
# Check backup directory
ls -la ./tmp/pi_backup/

# Manually specify export file
./scripts/restore_to_laptop.sh ./path/to/export.json
```

**"Permission denied" on scripts**
```bash
# Make scripts executable
chmod +x scripts/*.sh
```

### Recovery Options

If sync fails completely:

1. **Use SQLite file backup**
   ```bash
   # Copy raw SQLite files manually (see above)
   ```

2. **Start fresh**
   ```bash
   # Clear local data and re-import
   kamal app exec -d local --reuse "rm -f /rails/storage/production*.sqlite3"
   ./scripts/restore_to_laptop.sh
   ```

3. **Check application logs**
   ```bash
   kamal logs -d local    # For laptop issues
   kamal logs             # For Pi issues  
   ```

## File Locations

### On Your Machine
- Scripts: `./scripts/`
- Backups: `./tmp/pi_backup/`, `./tmp/laptop_backup/`
- Configs: `config/deploy.yml`, `config/deploy.local.yml`

### In Containers (via Kamal)
- Database: `/rails/storage/production*.sqlite3`
- Temp files: `/rails/tmp/`
- Application: `/rails/`

### On Pi (SSH access)
- App directory: `~/routine/`
- Database: `~/routine/storage/production*.sqlite3`
- Docker volumes: Managed by Kamal

Remember: Always test your backup and restore process before you actually need it!