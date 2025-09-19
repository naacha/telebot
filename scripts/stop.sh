#!/bin/bash
# STB Stop Script

cd "$(dirname "$0")"

echo "🛑 Stopping STB HG680P Telegram Bot..."

# Stop Docker Compose services
docker-compose down

# Force stop any remaining containers
docker stop telegram-bot-stb telegram-bot 2>/dev/null || true

echo "✅ STB Telegram Bot stopped"
echo "💾 Data preserved in volumes"  
echo "🔄 Use ./start.sh to restart"
