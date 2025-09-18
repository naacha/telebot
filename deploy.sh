#!/bin/bash

# Complete Enhanced Deployment Script
# Handles everything from Docker install to bot startup
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🚀 Enhanced Telegram Bot Deployment${NC}"
echo -e "${CYAN}====================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ This script must be run as root${NC}"
    echo "Usage: sudo ./deploy.sh"
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
    echo -e "${GREEN}   ✅ Docker installed successfully${NC}"
    echo ""
fi

# Verify Docker is running
if ! systemctl is-active --quiet docker; then
    echo -e "${BLUE}🔄 Starting Docker service...${NC}"
    systemctl start docker
fi

echo -e "${GREEN}✅ Docker is ready${NC}"
echo ""

# Check for configuration
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}⚙️  Configuration file not found${NC}"
    echo "Creating .env from template..."

    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo -e "${GREEN}   ✅ Configuration template created${NC}"
    else
        echo -e "${RED}❌ .env.example not found${NC}"
        exit 1
    fi

    echo ""
    echo -e "${YELLOW}📝 Please configure the following in .env:${NC}"
    echo ""
    echo "1. BOT_TOKEN - Get from @BotFather on Telegram"
    echo "2. GOOGLE_CLIENT_ID - From Google Cloud Console"
    echo "3. GOOGLE_CLIENT_SECRET - From Google Cloud Console"
    echo ""
    echo -e "${BLUE}Commands to edit:${NC}"
    echo "nano .env       # Edit configuration"
    echo "sudo ./deploy.sh   # Run this script again"
    echo ""
    exit 0
fi

# Load and validate configuration
echo -e "${BLUE}🔍 Validating configuration...${NC}"
export $(cat .env | grep -v '^#' | xargs) 2>/dev/null || true

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
    echo -e "${RED}❌ Missing required configuration:${MISSING}${NC}"
    echo ""
    echo "Please edit .env file and set:"
    echo "$MISSING" | tr ' ' '\n' | sed 's/^/• /'
    echo ""
    echo "Edit with: nano .env"
    exit 1
fi

echo -e "${GREEN}✅ Configuration validated${NC}"
echo ""

# Set permissions for scripts
echo -e "${BLUE}🔧 Setting script permissions...${NC}"
chmod +x *.sh 2>/dev/null || true
echo -e "${GREEN}   ✅ Permissions set${NC}"

# Build and start
echo ""
echo -e "${BLUE}🔨 Building bot with enhanced features...${NC}"

if ./build.sh; then
    echo ""
    echo -e "${BLUE}🚀 Starting bot services...${NC}"

    if ./start.sh; then
        # Get final configuration
        export $(cat .env | grep -v '^#' | xargs) 2>/dev/null || true
        OAUTH_PORT=${OAUTH_PORT:-8080}

        echo ""
        echo -e "${CYAN}✅ DEPLOYMENT SUCCESSFUL!${NC}"
        echo -e "${CYAN}=========================${NC}"
        echo ""

        echo -e "${GREEN}🎉 Bot is now running and ready!${NC}"
        echo ""

        echo -e "${BLUE}📋 Next Steps:${NC}"
        echo ""
        echo "1️⃣  Test bot in Telegram:"
        echo "   • Send /start to your bot"
        echo "   • Bot will show professional interface"
        echo ""

        echo "2️⃣  Connect cloud storage:"
        echo "   • Send /auth command"
        echo "   • Complete Google OAuth2 flow"
        echo "   • OAuth port: ${OAUTH_PORT}"
        echo ""

        if [ $OAUTH_PORT -ne 8080 ]; then
            echo "3️⃣  Update Google Cloud Console:"
            echo "   • Go to APIs & Services > Credentials"
            echo "   • Edit your OAuth 2.0 Client"
            echo "   • Update redirect URI to:"
            echo "     http://localhost:${OAUTH_PORT}"
            echo ""
        fi

        echo "4️⃣  Test bot features:"
        echo "   • /speedtest - Network speed test"
        echo "   • /d [link] - Download files"
        echo "   • @botname commands - Inline queries"
        echo ""

        echo -e "${BLUE}🔧 Management Commands:${NC}"
        echo ""
        echo "./status.sh    - Check bot status & port info"
        echo "./logs.sh      - View real-time logs"
        echo "./restart.sh   - Restart bot safely"
        echo "./stop.sh      - Stop bot"
        echo "./build.sh     - Rebuild with updates"
        echo ""

        echo -e "${BLUE}✨ Enhanced Features Available:${NC}"
        echo ""
        echo "• ✅ OAuth2 Google Drive (Error 400 fixed)"
        echo "• ✅ Speedtest with Ookla integration"
        echo "• ✅ Inline queries for BotFather"
        echo "• ✅ Owner commands (@zalhera management)"
        echo "• ✅ Auto port detection (no conflicts)"
        echo "• ✅ Enhanced container management"
        echo "• ✅ Professional user interface"
        echo ""

        echo -e "${GREEN}🎯 Bot is production-ready!${NC}"
        echo ""

    else
        echo -e "${RED}❌ Failed to start bot${NC}"
        echo "Check logs: ./logs.sh"
        exit 1
    fi
else
    echo -e "${RED}❌ Failed to build bot${NC}"
    echo "Check build output above for errors"
    exit 1
fi
