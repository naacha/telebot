#!/bin/bash
# STB Stop Script

cd "$(dirname "$0")"

echo "🛑 Stopping STB HG680P Telegram Bot..."

docker-compose down

echo "✅ STB Telegram Bot stopped"
echo "💾 Data preserved in volumes"
echo "🔄 Use ./start.sh to restart"
