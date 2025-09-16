#!/bin/bash
echo "🔓 OAuth2 Bot Shell Access"
echo "=========================="
cd "$(dirname "$0")"

if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

CONTAINER_NAME=${CONTAINER_NAME:-"leech-bot"}

if docker ps -q -f name=${CONTAINER_NAME} > /dev/null; then
    echo "⚠️ ROOT shell access"
    echo "OAuth2 token location: /app/data/google_token.json"
    echo ""
    docker exec -u root -it ${CONTAINER_NAME} /bin/bash
else
    echo "❌ Container not running"
fi
