#!/bin/bash
cd "$(dirname "$0")"
export $(cat .env | grep -v '^#' | xargs) 2>/dev/null || true

CONTAINER_NAME=${CONTAINER_NAME:-telegram-bot}

echo "🔄 Restarting Bot..."

if docker ps -q -f name=${CONTAINER_NAME} > /dev/null; then
    docker restart ${CONTAINER_NAME}
    echo "✅ Bot restarted"
else
    echo "❌ Bot not running, use ./start.sh"
fi
