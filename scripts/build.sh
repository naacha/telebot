#!/bin/bash
# STB Build Script with Forced Docker Cleanup

cd "$(dirname "$0")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🔨 Building STB HG680P Telegram Bot${NC}"
echo -e "${CYAN}===================================${NC}"
echo ""

# Load environment variables
if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs) 2>/dev/null || true
fi

# Force stop and remove ALL related containers
echo -e "${BLUE}🛑 Force stopping and removing ALL related containers...${NC}"

# Stop containers by name patterns
docker stop telegram-bot-stb telegram-bot 2>/dev/null || true
docker rm -f telegram-bot-stb telegram-bot 2>/dev/null || true

# Stop containers by image patterns
CONTAINERS=$(docker ps -aq --filter ancestor=telegram-bot:latest 2>/dev/null || echo "")
if [ ! -z "$CONTAINERS" ]; then
    echo "Stopping containers with telegram-bot image..."
    echo "$CONTAINERS" | xargs -r docker stop 2>/dev/null || true
    echo "$CONTAINERS" | xargs -r docker rm -f 2>/dev/null || true
fi

# Remove images
echo -e "${BLUE}🗑️ Removing old images...${NC}"
docker rmi telegram-bot:latest telegram-bot-stb:latest 2>/dev/null || true

# Clean Docker system
echo -e "${BLUE}🧹 Cleaning Docker system...${NC}"
docker system prune -f 2>/dev/null || true

echo -e "${GREEN}✅ Docker force cleanup completed${NC}"
echo ""

# Show system info
echo -e "${BLUE}📱 STB System Info:${NC}"
echo "Architecture: $(uname -m)"
echo "Memory: $(free -h | awk '/^Mem:/ {print $7}') available"
echo "Storage: $(df -h / | awk 'NR==2 {print $4}') available"
echo ""

# Build new image
echo -e "${BLUE}🔨 Building STB-optimized Docker image...${NC}"
echo "Building with ARM64 platform support..."

if docker-compose build --no-cache --force-rm; then
    echo ""
    echo -e "${GREEN}✅ STB Build completed successfully!${NC}"
    echo ""
    echo -e "${CYAN}📋 Build Summary:${NC}"
    echo "• Force Docker cleanup: ✅ Completed"
    echo "• ARM64 optimization: ✅ Applied"
    echo "• Channel subscription: ✅ Implemented"
    echo "• Port auto-detection: ✅ Ready"
    echo "• Inline commands: ✅ Supported"
    echo "• BotFather commands: ✅ Supported"
    echo ""
    echo -e "${BLUE}📢 Features Added:${NC}"
    echo "• Channel @ZalheraThink subscription check"
    echo "• Inline query support"
    echo "• @username command support"
    echo "• Reply-to-message download"
    echo "• Port conflict auto-resolution"
    echo ""
    echo -e "${GREEN}🚀 Ready to start: ./start.sh${NC}"
else
    echo ""
    echo -e "${RED}❌ Build failed${NC}"
    echo "Check logs above for errors"
    exit 1
fi
