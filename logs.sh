#!/bin/bash
cd "$(dirname "$0")"

BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs) 2>/dev/null || true
fi

CONTAINER_NAME=${CONTAINER_NAME:-telegram-bot}

echo -e "${BLUE}📋 ULTIMATE FIXED Bot Logs${NC}"
echo -e "${BLUE}===========================${NC}"
echo ""

if docker ps -q -f name=${CONTAINER_NAME} > /dev/null 2>&1; then
    echo "Following logs for: ${CONTAINER_NAME} (all ultimate fixes applied)"
    echo "Press Ctrl+C to exit"
    echo ""
    docker logs -f --tail=50 ${CONTAINER_NAME}
else
    echo -e "${RED}❌ Container not found${NC}"
    echo "🔨 Build first: ./build.sh"
fi