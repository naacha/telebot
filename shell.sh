#!/bin/bash
cd "$(dirname "$0")"

BLUE='\033[0;34m'
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs) 2>/dev/null || true
fi

CONTAINER_NAME=${CONTAINER_NAME:-telegram-bot}

echo -e "${BLUE}🔓 Bot Shell Access${NC}"
echo -e "${BLUE}===================${NC}"
echo ""

if docker ps -q -f name=${CONTAINER_NAME} > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Entering container shell...${NC}"
    echo "Type 'exit' to return to host"
    echo ""
    docker exec -it ${CONTAINER_NAME} /bin/bash
else
    echo -e "${RED}❌ Bot container not running${NC}"
    echo ""
    echo "🚀 Start bot first: ./start.sh"
fi