#!/bin/bash
# STB Restart Script

echo "🔄 Restarting STB HG680P Telegram Bot..."

# Force cleanup before restart
./scripts/build.sh

# Start services
./start.sh
