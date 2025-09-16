#!/bin/bash
echo "🔄 Restarting OAuth2 Bot"
cd "$(dirname "$0")"

if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

CONTAINER_NAME=${CONTAINER_NAME:-"leech-bot"}

if docker ps -q -f name=${CONTAINER_NAME} > /dev/null; then
    echo "🔄 Restarting: ${CONTAINER_NAME}"
    docker restart ${CONTAINER_NAME}
    echo "✅ Container restarted"
    echo "🔑 OAuth2 token preserved"
else
    echo "❌ Container not running"
fi
