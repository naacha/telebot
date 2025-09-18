#!/bin/bash
cd "$(dirname "$0")"
export $(cat .env | grep -v '^#' | xargs) 2>/dev/null || true

CONTAINER_NAME=${CONTAINER_NAME:-telegram-bot}
IMAGE_NAME=${IMAGE_NAME:-telegram-bot:latest}

echo "🚀 Starting Telegram Bot..."

if docker ps -q -f name=${CONTAINER_NAME} > /dev/null; then
    echo "🛑 Stopping existing container..."
    docker stop ${CONTAINER_NAME}
fi

if docker ps -aq -f name=${CONTAINER_NAME} > /dev/null; then
    echo "🗑️ Removing existing container..."
    docker rm ${CONTAINER_NAME}
fi

docker run -d \
    --name ${CONTAINER_NAME} \
    --user root \
    --restart unless-stopped \
    --env-file .env \
    -v $(pwd)/data:/app/data \
    -v $(pwd)/downloads:/app/downloads \
    -v $(pwd)/logs:/app/logs \
    -p 8080:8080 \
    ${IMAGE_NAME}

sleep 3

if docker ps -q -f name=${CONTAINER_NAME} > /dev/null; then
    echo "✅ Bot started successfully!"
    echo "📋 Management: ./status.sh, ./logs.sh, ./stop.sh"
else
    echo "❌ Failed to start"
    docker logs ${CONTAINER_NAME}
fi
