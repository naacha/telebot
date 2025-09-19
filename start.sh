#!/bin/bash
# STB HG680P Start Script with Port Auto-detection and Docker Cleanup

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

# Force stop existing containers
echo -e "${BLUE}🛑 Force stopping existing containers...${NC}"
docker stop telegram-bot-stb 2>/dev/null || true
docker stop telegram-bot 2>/dev/null || true
docker rm -f telegram-bot-stb 2>/dev/null || true
docker rm -f telegram-bot 2>/dev/null || true

# Check required variables
MISSING=""
if [ -z "$BOT_TOKEN" ] || [ "$BOT_TOKEN" = "your_bot_token_here" ]; then
    MISSING="$MISSING BOT_TOKEN"
fi

if [ -z "$BOT_USERNAME" ] || [ "$BOT_USERNAME" = "your_bot_username_without_@" ]; then
    MISSING="$MISSING BOT_USERNAME"
fi

if [ ! -z "$MISSING" ]; then
    echo -e "${RED}❌ Missing required configuration:${MISSING}${NC}"
    echo "Please edit .env file and configure all required values"
    exit 1
fi

# Port auto-detection function
find_available_port() {
    local start_port=$1
    local max_attempts=50
    local port=$start_port

    echo -e "${BLUE}🔍 Checking port availability starting from ${start_port}...${NC}"

    while [ $port -lt $((start_port + max_attempts)) ]; do
        # Check if port is in use
        if ! netstat -tuln 2>/dev/null | grep -q ":$port "; then
            # Double check with Docker
            if ! docker ps --filter "publish=$port" --format "{{.Names}}" 2>/dev/null | grep -q .; then
                echo -e "${GREEN}   ✅ Port $port is available${NC}"
                return $port
            fi
        fi

        echo -e "${YELLOW}   ⚠️ Port $port is in use, trying next...${NC}"
        port=$((port + 1))
    done

    echo -e "${RED}❌ Could not find available port in range $start_port-$((start_port + max_attempts))${NC}"
    exit 1
}

# Auto-detect available port
OAUTH_PORT=${OAUTH_PORT:-8080}
ORIGINAL_PORT=$OAUTH_PORT

# Find available port
find_available_port $OAUTH_PORT
OAUTH_PORT=$?

# Update .env if port changed
if [ $OAUTH_PORT -ne $ORIGINAL_PORT ]; then
    echo -e "${BLUE}📝 Updating .env with new port ${OAUTH_PORT}...${NC}"

    if grep -q "OAUTH_PORT=" .env; then
        sed -i "s/OAUTH_PORT=.*/OAUTH_PORT=$OAUTH_PORT/" .env
    else
        echo "OAUTH_PORT=$OAUTH_PORT" >> .env
    fi

    # Reload environment
    export $(cat .env | grep -v '^#' | xargs) 2>/dev/null || true
fi

echo -e "${BLUE}📱 STB Information:${NC}"
echo "Model: HG680P"
echo "OS: Armbian $(cat /etc/armbian-release | grep VERSION | cut -d'=' -f2 2>/dev/null || echo '25.11')"
echo "Architecture: $(uname -m)"
echo "OAuth Port: $OAUTH_PORT"
echo ""

# Create required directories
mkdir -p data downloads logs credentials
chmod -R 755 data downloads logs credentials

# Build and start services
echo -e "${BLUE}🔨 Building STB-optimized Docker images...${NC}"
docker-compose build --no-cache

echo -e "${BLUE}🚀 Starting STB Telegram Bot services...${NC}"
OAUTH_PORT=$OAUTH_PORT docker-compose up -d

# Wait for services to start
echo -e "${BLUE}⏳ Waiting for services to initialize...${NC}"
sleep 15

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
    echo "OAuth Port: $OAUTH_PORT"
    echo ""

    echo -e "${CYAN}🎉 Bot is ready! Test it in Telegram with /start${NC}"
    echo ""
    echo -e "${BLUE}📢 Important: Users must join @ZalheraThink to use the bot${NC}"
    echo ""
    echo -e "${BLUE}📋 Management Commands:${NC}"
    echo "./logs.sh    - View live logs"
    echo "./stop.sh    - Stop the bot"
    echo "./restart.sh - Restart the bot"
    echo "./status.sh  - Check status"
    echo ""

    if [ $OAUTH_PORT -ne $ORIGINAL_PORT ]; then
        echo -e "${YELLOW}⚠️ Port changed from $ORIGINAL_PORT to $OAUTH_PORT${NC}"
        echo "Google OAuth redirect URI should be: http://localhost:$OAUTH_PORT"
        echo ""
    fi

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
