#!/bin/bash
cd "$(dirname "$0")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs) 2>/dev/null || true
fi

CONTAINER_NAME=${CONTAINER_NAME:-telegram-bot}
OAUTH_PORT=${OAUTH_PORT:-8080}

echo -e "${CYAN}📊 ULTIMATE FIXED Bot Status${NC}"
echo -e "${CYAN}============================${NC}"
echo ""

if docker ps -q -f name=${CONTAINER_NAME} > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Status: RUNNING${NC}"
    echo -e "${GREEN}🔌 OAuth Port: ${OAUTH_PORT}${NC}"
    echo -e "${GREEN}🌐 OAuth URI: http://localhost:${OAUTH_PORT}${NC}"
    echo ""

    # Health check
    HEALTH=$(docker inspect ${CONTAINER_NAME} --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
    if [ "$HEALTH" = "healthy" ]; then
        echo -e "${GREEN}💚 Health: Healthy${NC}"
    else
        echo -e "${YELLOW}💛 Health: ${HEALTH}${NC}"
    fi
    echo ""

    echo -e "${BLUE}🤖 Bot Features (ULTIMATE FIXED):${NC}"
    echo "• ✅ Platform requirement (removed from requirements.txt)"
    echo "• ✅ OAuth2 Google Drive (response_type conflict FIXED)"
    echo "• ✅ Speedtest with Ookla (architecture detection FIXED)"
    echo "• ✅ Docker health check format (ULTIMATE FIXED)"
    echo "• ✅ Container startup (clean and stable)"
    echo "• ✅ Inline queries (@botname commands)"
    echo "• ✅ Owner commands (@zalhera management)"
    echo "• ✅ Auto port detection & management"

else
    echo -e "${RED}❌ Status: CONTAINER NOT FOUND${NC}"
    echo ""
    echo -e "${BLUE}🔨 Setup Options:${NC}"
    echo "./build.sh     - Build with ultimate fixes"
    echo "./deploy.sh    - Complete deployment"
fi