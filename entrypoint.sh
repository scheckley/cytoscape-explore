#!/bin/bash

# Ensure Chrome directories exist and have correct permissions
mkdir -p $HOME/.local/share/applications
mkdir -p $HOME/.config/google-chrome
mkdir -p $HOME/.cache/google-chrome

npm run clean
npm run build
google-chrome --headless &
cd /home/appuser/app && npm run start
