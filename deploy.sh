#!/bin/bash

# Complete Telegram Bot Deployment Script
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🚀 Telegram Bot Deployment${NC}"
echo -e "${CYAN}===========================${NC}"
echo ""

# Check root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Run as root: sudo ./deploy.sh${NC}"
    exit 1
fi

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo -e "${BLUE}🐳 Installing Docker...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    systemctl enable docker
    systemctl start docker
    rm get-docker.sh
fi

# Check configuration
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}⚙️ Creating configuration file...${NC}"
    cp .env.example .env

    echo -e "${YELLOW}📝 Please configure the following:${NC}"
    echo "1. BOT_TOKEN from @BotFather"
    echo "2. GOOGLE_CLIENT_ID from Google Cloud"
    echo "3. GOOGLE_CLIENT_SECRET from Google Cloud"
    echo ""
    echo "Edit: nano .env"
    echo "Then run: ./deploy.sh"
    exit 0
fi

# Load configuration
export $(cat .env | grep -v '^#' | xargs)

# Validate configuration
MISSING=""
if [ -z "$BOT_TOKEN" ] || [ "$BOT_TOKEN" = "your_bot_token_here" ]; then
    MISSING="$MISSING BOT_TOKEN"
fi

if [ -z "$GOOGLE_CLIENT_ID" ] || [[ "$GOOGLE_CLIENT_ID" == *"your-client-id"* ]]; then
    MISSING="$MISSING GOOGLE_CLIENT_ID"
fi

if [ -z "$GOOGLE_CLIENT_SECRET" ] || [[ "$GOOGLE_CLIENT_SECRET" == *"your-client-secret"* ]]; then
    MISSING="$MISSING GOOGLE_CLIENT_SECRET"
fi

if [ ! -z "$MISSING" ]; then
    echo -e "${RED}❌ Missing configuration:${MISSING}${NC}"
    echo "Please edit .env file: nano .env"
    exit 1
fi

echo -e "${GREEN}✅ Configuration validated${NC}"

# Stop existing container
echo -e "${BLUE}🛑 Stopping existing container...${NC}"
docker stop ${CONTAINER_NAME:-telegram-bot} 2>/dev/null || true
docker rm ${CONTAINER_NAME:-telegram-bot} 2>/dev/null || true

# Build image
echo -e "${BLUE}🔨 Building bot image...${NC}"
cp .env .env.build
docker build --no-cache -t ${IMAGE_NAME:-telegram-bot:latest} .
rm .env.build

# Start container
echo -e "${BLUE}🚀 Starting bot container...${NC}"
docker run -d \
    --name ${CONTAINER_NAME:-telegram-bot} \
    --user root \
    --restart unless-stopped \
    --env-file .env \
    -v $(pwd)/data:/app/data \
    -v $(pwd)/downloads:/app/downloads \
    -v $(pwd)/logs:/app/logs \
    -p 8080:8080 \
    ${IMAGE_NAME:-telegram-bot:latest}

echo "⏳ Waiting for bot to start..."
sleep 10

if docker ps | grep -q ${CONTAINER_NAME:-telegram-bot}; then
    echo -e "${GREEN}✅ Bot deployed successfully!${NC}"
    echo ""
    echo -e "${CYAN}📋 Next Steps:${NC}"
    echo "1. Send /start to your bot in Telegram"
    echo "2. Use /auth to connect cloud storage"
    echo "3. Test with /d [file-link]"
    echo ""
    echo -e "${CYAN}🔧 Management:${NC}"
    echo "./status.sh    - Check status"
    echo "./logs.sh      - View logs"
    echo "./stop.sh      - Stop bot"
    echo ""
    echo -e "${GREEN}🎉 Deployment Complete!${NC}"
else
    echo -e "${RED}❌ Deployment failed${NC}"
    echo "Check logs: docker logs ${CONTAINER_NAME:-telegram-bot}"
fi
