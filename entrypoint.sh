#!/bin/bash
set -e  # Exit on error

# Ensure Chrome directories exist and have correct permissions
mkdir -p $HOME/.local/share/applications
mkdir -p $HOME/.config/google-chrome
mkdir -p $HOME/.cache/google-chrome
mkdir -p $HOME/.config

# Ensure npm has required dependencies
npm install -g npm-run-all

# Clean and build with proper directory permissions
cd /app  # Make sure we're in the right directory
npm run clean
npm run build

# Start Chrome in headless mode with OpenShift-compatible flags
google-chrome --headless --no-sandbox --disable-dev-shm-usage --disable-gpu &

# Start the application
npm run start
