#!/bin/bash
echo "🛑 Stopping OAuth2 Bot"
cd "$(dirname "$0")"

if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

CONTAINER_NAME=${CONTAINER_NAME:-"leech-bot"}

if docker ps -q -f name=${CONTAINER_NAME} > /dev/null; then
    echo "🛑 Stopping: ${CONTAINER_NAME}"
    docker stop ${CONTAINER_NAME}
    echo "✅ Container stopped"
else
    echo "ℹ️ Container not running"
fi
