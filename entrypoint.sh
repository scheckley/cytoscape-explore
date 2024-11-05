#!/bin/bash
set -e  # Exit on error

# Start Chrome in headless mode with OpenShift-compatible flags
google-chrome --headless --no-sandbox --disable-dev-shm-usage --disable-gpu &

# Clean and build
npm run clean
npm run build

# Start the application
npm run start