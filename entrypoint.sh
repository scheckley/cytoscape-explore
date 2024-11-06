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

# Start Chrome with all output redirected to /dev/null
# The parentheses create a subshell to contain the chrome process
(
    google-chrome ${CHROMIUM_FLAGS} \
        --disable-logging \
        --v=0 \
        --log-level=3 \
        --silent \
        --disable-crashpad \
        2>/dev/null >/dev/null & 
)

# Give Chrome a moment to start
sleep 2

# Start the application
log "Starting application..."
exec npm run start