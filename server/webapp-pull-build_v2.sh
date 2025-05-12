#!/bin/bash
# Enhanced deployment script for Jetwash-mobile with error handling and debugging

# Exit on any error
set -e

# Define colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print section header
print_header() {
  echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}🚀 $1 ${NC}"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# Print step
print_step() {
  echo -e "${GREEN}➤ $1${NC}"
}

# Print error
print_error() {
  echo -e "${RED}❌ ERROR: $1${NC}"
}

# Print success
print_success() {
  echo -e "${PURPLE}✅ $1${NC}"
}

# Print commands before execution (but keep it clean)
# set -x is removed to avoid cluttering the colorized output

# Navigate to project directory
print_header "JETWASH DEPLOYMENT SCRIPT"
print_step "Navigating to project directory..."
cd /home/marco/Jetwash-mobile
print_success "Current directory: $(pwd)"

# Pull latest changes
print_header "UPDATING CODE"
print_step "Pulling latest changes from git repository..."
git pull
print_success "Code updated successfully!"

# Install dependencies
print_header "INSTALLING DEPENDENCIES"
print_step "Installing project dependencies with pnpm..."
pnpm install
print_success "Dependencies installed successfully!"

# Use the existing pm2:clean-restart script
print_header "REBUILDING & RESTARTING APPLICATION"
print_step "Performing clean restart with fresh build..."
pnpm run pm2:clean-restart || {
  print_error "Failed to restart application"
  exit 1
}
print_success "Application rebuilt and restarted successfully!"

# Display logs
print_header "APPLICATION LOGS"
print_step "Displaying recent application logs..."
pnpm run pm2:logs -- --lines 20
print_success "Deployment completed successfully!"

print_header "DEPLOYMENT COMPLETE"
echo -e "${BLUE}Jetwash application has been deployed at $(date)${NC}"
echo -e "${BLUE}Thank you for using the deployment script!${NC}"

