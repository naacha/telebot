#!/bin/bash
# STB HG680P Start Script

cd "$(dirname "$0")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🚀 Starting STB HG680P Telegram Bot${NC}"
echo -e "${CYAN}===================================${NC}"
echo ""

# Load environment variables
if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs) 2>/dev/null || true
else
    echo -e "${RED}❌ .env file not found${NC}"
    echo "Copy .env.example to .env and configure it"
    exit 1
fi

# Check required variables
MISSING=""
if [ -z "$BOT_TOKEN" ] || [ "$BOT_TOKEN" = "your_bot_token_here" ]; then
    MISSING="$MISSING BOT_TOKEN"
fi

if [ ! -z "$MISSING" ]; then
    echo -e "${RED}❌ Missing required configuration:${MISSING}${NC}"
    echo "Please edit .env file and configure all required values"
    exit 1
fi

# Show STB info
echo -e "${BLUE}📱 STB Information:${NC}"
echo "Model: HG680P"
echo "OS: Armbian $(cat /etc/armbian-release | grep VERSION | cut -d'=' -f2 2>/dev/null || echo '25.11')"
echo "Architecture: $(uname -m)"
echo "Memory: $(free -h | awk '/^Mem:/ {print $2}') total, $(free -h | awk '/^Mem:/ {print $7}') available"
echo ""

# Check if already running
if docker-compose ps | grep -q "Up"; then
    echo -e "${YELLOW}⚠️ Bot is already running${NC}"
    echo "Use ./restart.sh to restart or ./stop.sh to stop"
    exit 0
fi

# Create required directories
mkdir -p data downloads logs credentials
chmod -R 755 data downloads logs credentials

# Build and start services
echo -e "${BLUE}🔨 Building STB-optimized Docker images...${NC}"
docker-compose build --no-cache

echo -e "${BLUE}🚀 Starting STB Telegram Bot services...${NC}"
docker-compose up -d

# Wait for services to start
echo -e "${BLUE}⏳ Waiting for services to initialize...${NC}"
sleep 10

# Check if services are running
if docker-compose ps | grep -q "Up"; then
    echo ""
    echo -e "${GREEN}✅ STB Telegram Bot started successfully!${NC}"
    echo ""

    # Show service status
    echo -e "${BLUE}📊 Service Status:${NC}"
    docker-compose ps
    echo ""

    # Show container logs (last few lines)
    echo -e "${BLUE}📋 Recent logs:${NC}"
    docker-compose logs --tail=10
    echo ""

    # Show STB system resource usage
    echo -e "${BLUE}💻 STB Resource Usage:${NC}"
    echo "Memory: $(free -h | awk '/^Mem:/ {print $3}') used / $(free -h | awk '/^Mem:/ {print $2}') total"
    echo "Storage: $(df -h / | awk 'NR==2 {print $3}') used / $(df -h / | awk 'NR==2 {print $2}') total"
    echo "Load: $(uptime | cut -d',' -f3-)"
    echo ""

    echo -e "${CYAN}🎉 Bot is ready! Test it in Telegram with /start${NC}"
    echo ""
    echo -e "${BLUE}📋 Management Commands:${NC}"
    echo "./logs.sh    - View live logs"
    echo "./stop.sh    - Stop the bot"
    echo "./restart.sh - Restart the bot"
    echo "./status.sh  - Check status"
    echo ""

else
    echo ""
    echo -e "${RED}❌ Failed to start STB Telegram Bot${NC}"
    echo ""
    echo -e "${BLUE}🔍 Checking logs for errors:${NC}"
    docker-compose logs --tail=20
    echo ""
    echo -e "${YELLOW}💡 Troubleshooting:${NC}"
    echo "1. Check .env configuration"
    echo "2. Verify Docker and Docker Compose installation"
    echo "3. Check STB system resources"
    echo "4. Review logs above for specific errors"
    exit 1
fi
