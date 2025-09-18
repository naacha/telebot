#!/bin/bash

# Enhanced Start Script with Smart Port Management
cd "$(dirname "$0")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Load environment
if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs) 2>/dev/null || true
fi

CONTAINER_NAME=${CONTAINER_NAME:-telegram-bot}
IMAGE_NAME=${IMAGE_NAME:-telegram-bot:latest}
OAUTH_PORT=${OAUTH_PORT:-8080}

echo -e "${BLUE}🚀 Starting Enhanced Telegram Bot...${NC}"
echo "📦 Container: ${CONTAINER_NAME}"
echo "🖼️  Image: ${IMAGE_NAME}"
echo "🔌 OAuth Port: ${OAUTH_PORT}"
echo ""

# Verify image exists
if ! docker images ${IMAGE_NAME} --format "{{.Repository}}" | grep -q "telegram-bot"; then
    echo -e "${YELLOW}⚠️  Image not found. Building first...${NC}"
    if ! ./build.sh; then
        echo -e "${RED}❌ Build failed${NC}"
        exit 1
    fi
fi

# Clean existing containers
if docker ps -q -f name=${CONTAINER_NAME} > /dev/null 2>&1; then
    echo -e "${YELLOW}🛑 Stopping existing container...${NC}"
    docker stop ${CONTAINER_NAME} >/dev/null 2>&1
fi

if docker ps -aq -f name=${CONTAINER_NAME} > /dev/null 2>&1; then
    echo -e "${YELLOW}🗑️  Removing existing container...${NC}"
    docker rm -f ${CONTAINER_NAME} >/dev/null 2>&1
fi

# Verify port is available
if netstat -tuln 2>/dev/null | grep -q ":${OAUTH_PORT} "; then
    echo -e "${YELLOW}⚠️  Port ${OAUTH_PORT} appears to be in use${NC}"
    echo "   Running build.sh to find alternative port..."
    if ! ./build.sh; then
        echo -e "${RED}❌ Auto port detection failed${NC}"
        exit 1
    fi
    # Reload environment after build
    export $(cat .env | grep -v '^#' | xargs) 2>/dev/null || true
    OAUTH_PORT=${OAUTH_PORT:-8080}
fi

echo ""
echo -e "${BLUE}🔄 Starting container with optimized settings...${NC}"

# Start container with full configuration
docker run -d \
    --name ${CONTAINER_NAME} \
    --user root \
    --restart unless-stopped \
    --env-file .env \
    --health-cmd="python -c 'print("OK")'" \
    --health-interval=30s \
    --health-timeout=10s \
    --health-retries=3 \
    -v $(pwd)/data:/app/data \
    -v $(pwd)/downloads:/app/downloads \
    -v $(pwd)/logs:/app/logs \
    -p ${OAUTH_PORT}:8080 \
    ${IMAGE_NAME}

if [ $? -eq 0 ]; then
    echo -e "${GREEN}   ✅ Container started successfully${NC}"
else
    echo -e "${RED}   ❌ Failed to start container${NC}"
    exit 1
fi

# Wait for container to initialize
echo "⏳ Waiting for bot to initialize..."
sleep 5

# Check container status
if docker ps -q -f name=${CONTAINER_NAME} > /dev/null 2>&1; then
    # Get container status
    STATUS=$(docker ps -f name=${CONTAINER_NAME} --format "{{.Status}}")

    echo ""
    echo -e "${GREEN}✅ Bot started successfully!${NC}"
    echo -e "${GREEN}📊 Status: ${STATUS}${NC}"
    echo -e "${GREEN}🔌 OAuth callback: http://localhost:${OAUTH_PORT}${NC}"
    echo ""
    echo -e "${BLUE}📋 Quick Commands:${NC}"
    echo "./status.sh    - Check detailed status"
    echo "./logs.sh      - View real-time logs"
    echo "./restart.sh   - Restart bot safely"
    echo ""
    echo -e "${BLUE}🤖 Bot Commands:${NC}"
    echo "/start         - Welcome & features"
    echo "/auth          - Connect Google Drive"
    echo "/speedtest     - Test network speed"
    echo "/stats         - View statistics"
    echo ""
    if [ $OAUTH_PORT -ne 8080 ]; then
        echo -e "${YELLOW}⚠️  Remember to update Google Cloud Console redirect URI:${NC}"
        echo "   http://localhost:${OAUTH_PORT}"
        echo ""
    fi
    echo -e "${GREEN}🎉 Bot is ready for use!${NC}"
else
    echo ""
    echo -e "${RED}❌ Container failed to start properly${NC}"
    echo "📋 Checking logs..."
    docker logs --tail=10 ${CONTAINER_NAME} 2>/dev/null || echo "No logs available"
    echo ""
    echo "💡 Troubleshooting:"
    echo "• Check logs: ./logs.sh"
    echo "• Verify config: cat .env"
    echo "• Rebuild: ./build.sh"
    exit 1
fi
