#!/bin/bash
cd "$(dirname "$0")"
export $(cat .env | grep -v '^#' | xargs) 2>/dev/null || true

CONTAINER_NAME=${CONTAINER_NAME:-telegram-bot}

echo "🔓 Bot Shell Access"
echo "==================="

if docker ps -q -f name=${CONTAINER_NAME} > /dev/null; then
    echo "Entering container shell..."
    docker exec -it ${CONTAINER_NAME} /bin/bash
else
    echo "❌ Bot not running"
fi
