#!/bin/bash
set -e  # Exit on error

# Ensure Chrome directories exist and have correct permissions
mkdir -p $HOME/.local/share/applications
mkdir -p $HOME/.config/google-chrome
mkdir -p $HOME/.cache/google-chrome
mkdir -p $HOME/.config

# Ensure npm cache directories have correct permissions
mkdir -p $HOME/.npm/_cacache
mkdir -p $HOME/.npm/_logs
chmod -R g+rwx $HOME/.npm

# Clean and build with proper directory permissions
cd /app
npm run clean
npm run build

# Start Chrome in headless mode with OpenShift-compatible flags
google-chrome --headless --no-sandbox --disable-dev-shm-usage --disable-gpu &

# Start the application
npm run start