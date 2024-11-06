#!/bin/bash
set -e  # Exit on error

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Error handler
handle_error() {
    log "Error occurred in script at line: ${1}"
    exit 1
}

trap 'handle_error ${LINENO}' ERR

# Create runtime directories if they don't exist
mkdir -p /app/.config/google-chrome
mkdir -p /app/.cache/google-chrome

# Start Chrome in headless mode with restricted privileges
# Redirect output to avoid flooding logs
google-chrome ${CHROMIUM_FLAGS} > /dev/null 2>&1 &
CHROME_PID=$!

# Give Chrome a moment to start
sleep 2

# Check if Chrome is running
if ! kill -0 ${CHROME_PID} 2>/dev/null; then
    log "Warning: Chrome failed to start, but continuing..."
fi

# Start the application
log "Starting application..."
exec npm run start