#!/bin/bash
echo "📋 OAuth2 Bot Logs"
echo "=================="
cd "$(dirname "$0")"

if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

CONTAINER_NAME=${CONTAINER_NAME:-"leech-bot"}

if docker ps -q -f name=${CONTAINER_NAME} > /dev/null; then
    echo "Following logs for: ${CONTAINER_NAME}"
    echo "Look for OAuth2 authentication messages..."
    echo "Press Ctrl+C to exit"
    echo ""
    docker logs -f --tail=50 ${CONTAINER_NAME}
else
    echo "❌ Container not running"
fi
