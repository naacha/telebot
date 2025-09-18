#!/bin/bash
cd "$(dirname "$0")"
export $(cat .env | grep -v '^#' | xargs) 2>/dev/null || true

CONTAINER_NAME=${CONTAINER_NAME:-telegram-bot}

echo "📋 Bot Logs"
echo "==========="

if docker ps -q -f name=${CONTAINER_NAME} > /dev/null; then
    echo "Following logs for: ${CONTAINER_NAME}"
    echo "Press Ctrl+C to exit"
    echo ""
    docker logs -f --tail=50 ${CONTAINER_NAME}
else
    echo "❌ Bot not running"
fi
