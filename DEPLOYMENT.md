# Kamal Deployment Instructions

This document explains how to deploy the Routine Tracker application to both your Raspberry Pi (home.local) and your laptop (localhost) for travel use.

## Prerequisites

### For Pi Deployment (home.local)
- Ensure your Raspberry Pi is accessible at `home.local`
- SSH key `~/.ssh/home.local` is configured and accessible
- Docker is installed on the Pi
- User `joe` exists on the Pi with sudo privileges

### For Local Deployment (localhost)
- Docker is installed on your laptop
- Current user has docker privileges (member of docker group)
- Port 3000 is available on localhost

## Deployment Commands

### Deploy to Raspberry Pi (Default)
```bash
# Deploy to Pi using default configuration
kamal deploy

# Alternative explicit command
kamal deploy -d production
```

### Deploy to Local Laptop
```bash
# Deploy to localhost using local configuration
kamal deploy -d local
```

## Configuration Files

- `config/deploy.yml` - Default configuration for Raspberry Pi deployment
- `config/deploy.local.yml` - Local laptop deployment configuration

## Environment Variables

Both deployments use these environment variables:
- `APPLICATION_HOST` - Automatically set (home.local for Pi, localhost for local)
- `RAILS_MASTER_KEY` - Your Rails credentials key
- `SMTP_PASSWORD` - Email password for notifications
- `KAMAL_REGISTRY_PASSWORD` - Docker registry password

## Key Differences Between Deployments

| Aspect | Pi Deployment | Local Deployment |
|--------|---------------|------------------|
| Host | home.local | localhost |
| Architecture | ARM v7 | AMD64 |
| SSH User | joe | current user |
| SSH Key | ~/.ssh/home.local | default |
| Volume | survey_storage | survey_storage_local |

## Useful Commands

### General Operations
```bash
# View app logs
kamal logs -d [local|production]

# Open Rails console
kamal console -d [local|production]

# Open shell in container
kamal shell -d [local|production]

# Open database console
kamal dbc -d [local|production]

# Stop application
kamal app stop -d [local|production]

# Start application
kamal app start -d [local|production]

# Restart application
kamal app restart -d [local|production]

# Remove all containers and images
kamal app remove -d [local|production]
```

### Building and Pushing Images
```bash
# Build and push new image
kamal build push

# Deploy latest image without building
kamal deploy --skip-push -d [local|production]
```

## Troubleshooting

### Common Issues
1. **SSH Connection Issues (Pi)**
   - Verify Pi is accessible: `ping home.local`
   - Test SSH connection: `ssh -i ~/.ssh/home.local joe@home.local`

2. **Docker Issues (Local)**
   - Ensure Docker is running: `systemctl status docker`
   - Check user permissions: `groups $USER` (should include docker)

3. **Port Conflicts (Local)**
   - Check if port 3000 is in use: `lsof -i :3000`
   - Stop conflicting services or change port in deploy.local.yml

### Health Checks
```bash
# Check if app is running (Pi)
curl http://home.local:3000/up

# Check if app is running (Local)
curl http://localhost:3000/up
```

## Next Steps

After deployment, see `DATABASE_SYNC.md` for instructions on syncing your database between the Pi and laptop for travel use.