#!/bin/bash
# Script to pull latest code, rebuild and restart with PM2

# Navigate to project directory
cd /home/marco/Jetwash-mobile

# Pull latest changes
git pull

# Install dependencies
pnpm install

# Build for production
pnpm run build:prod

# Check if PM2 is running the app
if pm2 list | grep -q "Jetwash"; then
  # Restart if already running
  pnpm run start_prod:restart
else
  # Start if not running
  pnpm run start_prod
fi

# Display logs
pm2 logs Jetwash --lines 50

