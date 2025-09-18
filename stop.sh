#!/bin/bash
cd "$(dirname "$0")"
export $(cat .env | grep -v '^#' | xargs) 2>/dev/null || true

CONTAINER_NAME=${CONTAINER_NAME:-telegram-bot}

echo "🛑 Stopping Telegram Bot..."

if docker ps -q -f name=${CONTAINER_NAME} > /dev/null; then
    docker stop ${CONTAINER_NAME}
    echo "✅ Bot stopped"
else
    echo "ℹ️ Bot not running"
fi
