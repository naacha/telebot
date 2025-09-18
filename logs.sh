#!/bin/bash
cd "$(dirname "$0")"

BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs) 2>/dev/null || true
fi

CONTAINER_NAME=${CONTAINER_NAME:-telegram-bot}

echo -e "${BLUE}📋 FIXED Bot Logs (Real-time)${NC}"
echo -e "${BLUE}==============================${NC}"
echo ""

if docker ps -q -f name=${CONTAINER_NAME} > /dev/null 2>&1; then
    echo "Following logs for: ${CONTAINER_NAME} (with fixes)"
    echo "Press Ctrl+C to exit"
    echo ""
    docker logs -f --tail=50 ${CONTAINER_NAME}
elif docker ps -aq -f name=${CONTAINER_NAME} > /dev/null 2>&1; then
    echo -e "${RED}❌ Bot not running${NC}"
    echo ""
    echo -e "${BLUE}📋 Last available logs:${NC}"
    docker logs --tail=30 ${CONTAINER_NAME} 2>/dev/null || echo "No logs available"
    echo ""
    echo "🚀 Start bot: ./start.sh"
else
    echo -e "${RED}❌ Container not found${NC}"
    echo "🔨 Build first: ./build.sh"
fi