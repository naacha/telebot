#!/bin/bash
cd "$(dirname "$0")"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs) 2>/dev/null || true
fi

CONTAINER_NAME=${CONTAINER_NAME:-telegram-bot}

echo -e "${BLUE}🔄 Restarting Bot Safely...${NC}"

if docker ps -q -f name=${CONTAINER_NAME} > /dev/null 2>&1; then
    echo -e "${YELLOW}🛑 Stopping current instance...${NC}"
    docker stop ${CONTAINER_NAME} >/dev/null 2>&1

    echo -e "${BLUE}⏳ Waiting 3 seconds...${NC}"
    sleep 3

    echo -e "${BLUE}🚀 Starting bot...${NC}"
    docker start ${CONTAINER_NAME} >/dev/null 2>&1

    sleep 3

    if docker ps -q -f name=${CONTAINER_NAME} > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Bot restarted successfully${NC}"
        echo ""
        echo "📊 Status: $(docker ps -f name=${CONTAINER_NAME} --format '{{.Status}}')"
        echo "🔌 OAuth Port: ${OAUTH_PORT:-8080}"
        echo ""
        echo "📋 Commands: ./status.sh | ./logs.sh"
    else
        echo -e "${RED}❌ Restart failed${NC}"
        echo ""
        echo "💡 Trying fresh start..."
        ./start.sh
    fi
else
    echo -e "${YELLOW}⚠️  Bot not running, starting fresh...${NC}"
    ./start.sh
fi