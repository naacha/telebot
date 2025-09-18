#!/bin/bash
cd "$(dirname "$0")"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs) 2>/dev/null || true
fi

CONTAINER_NAME=${CONTAINER_NAME:-telegram-bot}

echo -e "${BLUE}🛑 Stopping FIXED Telegram Bot...${NC}"

if docker ps -q -f name=${CONTAINER_NAME} > /dev/null 2>&1; then
    docker stop ${CONTAINER_NAME} >/dev/null 2>&1
    echo -e "${GREEN}✅ Bot stopped successfully${NC}"

    # Show final status
    echo "📊 Final status: $(docker ps -a -f name=${CONTAINER_NAME} --format '{{.Status}}')"
else
    echo -e "${BLUE}ℹ️  Bot is not running${NC}"
fi

echo ""
echo "🔄 To start again: ./start.sh"
echo "🔨 To rebuild: ./build.sh"