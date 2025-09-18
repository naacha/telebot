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

echo -e "${CYAN}📊 FIXED Bot Status${NC}"
echo -e "${CYAN}==================${NC}"
echo ""

if docker ps -q -f name=${CONTAINER_NAME} > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Status: RUNNING${NC}"
    echo -e "${GREEN}🔌 OAuth Port: ${OAUTH_PORT}${NC}"
    echo -e "${GREEN}🌐 OAuth URI: http://localhost:${OAUTH_PORT}${NC}"
    echo ""

    echo -e "${BLUE}📋 Container Information:${NC}"
    docker ps -f name=${CONTAINER_NAME} --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""

    echo -e "${BLUE}💾 Resource Usage:${NC}"
    docker stats ${CONTAINER_NAME} --no-stream --format "CPU: {{.CPUPerc}}\tMemory: {{.MemUsage}}\tNet I/O: {{.NetIO}}" 2>/dev/null || echo "Resource info unavailable"
    echo ""

    # Health check
    HEALTH=$(docker inspect ${CONTAINER_NAME} --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
    if [ "$HEALTH" = "healthy" ]; then
        echo -e "${GREEN}💚 Health: Healthy${NC}"
    elif [ "$HEALTH" = "unhealthy" ]; then
        echo -e "${RED}❤️  Health: Unhealthy${NC}"
    else
        echo -e "${YELLOW}💛 Health: ${HEALTH}${NC}"
    fi
    echo ""

    echo -e "${BLUE}🔧 Management Commands:${NC}"
    echo "./logs.sh      - View real-time logs"
    echo "./restart.sh   - Restart bot safely"
    echo "./stop.sh      - Stop bot"
    echo "./build.sh     - Rebuild with latest changes"
    echo ""

    echo -e "${BLUE}🤖 Bot Features Available (FIXED):${NC}"
    echo "• ✅ OAuth2 Google Drive (response_type conflict FIXED)"
    echo "• ✅ Speedtest with Ookla (architecture detection FIXED)"
    echo "• ✅ Inline queries (@botname commands)"
    echo "• ✅ Owner commands (@zalhera management)"
    echo "• ✅ Auto port detection & management"
    echo "• ✅ Enhanced error handling & timeouts"

elif docker ps -aq -f name=${CONTAINER_NAME} > /dev/null 2>&1; then
    STATUS=$(docker ps -a -f name=${CONTAINER_NAME} --format "{{.Status}}")
    echo -e "${YELLOW}⚠️  Status: NOT RUNNING${NC}"
    echo -e "${YELLOW}📊 Last Status: ${STATUS}${NC}"
    echo ""

    echo -e "${BLUE}🔍 Recent Logs:${NC}"
    docker logs --tail=10 ${CONTAINER_NAME} 2>/dev/null || echo "No logs available"
    echo ""

    echo -e "${BLUE}🚀 Start Options:${NC}"
    echo "./start.sh     - Start bot with fixes"
    echo "./build.sh     - Rebuild and start"

else
    echo -e "${RED}❌ Status: CONTAINER NOT FOUND${NC}"
    echo ""
    echo -e "${BLUE}🔨 Setup Options:${NC}"
    echo "./build.sh     - Build bot image with fixes"
    echo "./deploy.sh    - Complete deployment"
fi