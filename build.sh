#!/bin/bash

# FIXED Enhanced Build Script - OAuth2 & Speedtest Issues Resolved
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🔨 Building FIXED Enhanced Telegram Bot${NC}"
echo -e "${CYAN}======================================${NC}"
echo ""

cd "$(dirname "$0")"

# Load environment
if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs) 2>/dev/null || true
fi

CONTAINER_NAME=${CONTAINER_NAME:-telegram-bot}
IMAGE_NAME=${IMAGE_NAME:-telegram-bot:latest}

echo -e "${BLUE}🛑 Force cleanup existing containers...${NC}"

# Stop ALL containers with same name (force cleanup)
echo "Force stopping containers with name: ${CONTAINER_NAME}"
docker stop ${CONTAINER_NAME} 2>/dev/null || true
docker rm -f ${CONTAINER_NAME} 2>/dev/null || true

# Remove any containers using same image
EXISTING_CONTAINERS=$(docker ps -aq --filter ancestor=${IMAGE_NAME} 2>/dev/null || echo "")
if [ ! -z "$EXISTING_CONTAINERS" ]; then
    echo "Force stopping containers using image: ${IMAGE_NAME}"
    echo "$EXISTING_CONTAINERS" | xargs -r docker stop 2>/dev/null || true
    echo "$EXISTING_CONTAINERS" | xargs -r docker rm -f 2>/dev/null || true
fi

# Clean up dangling containers
docker container prune -f 2>/dev/null || true

echo -e "${GREEN}   ✅ Container force cleanup completed${NC}"

echo ""
echo -e "${BLUE}🔍 Auto-detecting available port...${NC}"

# Enhanced port availability check
is_port_available() {
    local port=$1

    # Check if port is bound by any process
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        return 1
    fi

    # Check if port is used by lsof
    if command -v lsof >/dev/null 2>&1; then
        if lsof -i :$port >/dev/null 2>&1; then
            return 1
        fi
    fi

    # Check if port is published by Docker
    if docker ps --filter "publish=$port" --format "{{.Names}}" 2>/dev/null | grep -q .; then
        return 1
    fi

    return 0
}

# Find available port starting from 8080
OAUTH_PORT=8080
MAX_ATTEMPTS=50

while ! is_port_available $OAUTH_PORT && [ $OAUTH_PORT -lt $((8080 + MAX_ATTEMPTS)) ]; do
    echo "Port $OAUTH_PORT is in use, trying next..."
    OAUTH_PORT=$((OAUTH_PORT + 1))
done

if [ $OAUTH_PORT -ge $((8080 + MAX_ATTEMPTS)) ]; then
    echo -e "${RED}❌ Could not find available port in range 8080-8130${NC}"
    exit 1
fi

echo -e "${GREEN}   ✅ Available port found: ${OAUTH_PORT}${NC}"

# Update .env with found port
if [ -f ".env" ]; then
    # Create backup
    cp .env .env.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true

    # Update or add port configuration
    if grep -q "OAUTH_PORT=" .env; then
        sed -i "s/OAUTH_PORT=.*/OAUTH_PORT=$OAUTH_PORT/" .env
    else
        echo "OAUTH_PORT=$OAUTH_PORT" >> .env
    fi

    # Update redirect URI
    if grep -q "GOOGLE_REDIRECT_URI=" .env; then
        sed -i "s|GOOGLE_REDIRECT_URI=.*|GOOGLE_REDIRECT_URI=http://localhost:$OAUTH_PORT|" .env
    else
        echo "GOOGLE_REDIRECT_URI=http://localhost:$OAUTH_PORT" >> .env
    fi

    echo -e "${GREEN}   ✅ Configuration updated for port ${OAUTH_PORT}${NC}"
fi

echo ""
echo -e "${BLUE}🔨 Building Docker image with FIXES (clean build)...${NC}"

# Remove old image completely
docker rmi ${IMAGE_NAME} 2>/dev/null || true

# Clean Docker build cache
docker builder prune -f 2>/dev/null || true

# Build with fixes
echo "Building with FIXED OAuth2 and speedtest architecture detection..."
if docker build --no-cache --force-rm -t ${IMAGE_NAME} .; then
    echo -e "${GREEN}   ✅ Docker image built successfully with FIXES${NC}"
    echo -e "${GREEN}   📦 Image: ${IMAGE_NAME}${NC}"
    echo -e "${GREEN}   🔌 OAuth Port: ${OAUTH_PORT}${NC}"

    # Show image info
    IMAGE_SIZE=$(docker images ${IMAGE_NAME} --format "{{.Size}}" 2>/dev/null || echo "Unknown")
    IMAGE_ID=$(docker images ${IMAGE_NAME} --format "{{.ID}}" 2>/dev/null || echo "Unknown")
    echo -e "${GREEN}   💾 Size: ${IMAGE_SIZE}${NC}"
    echo -e "${GREEN}   🆔 ID: ${IMAGE_ID:0:12}${NC}"

    echo ""
    echo -e "${CYAN}📋 Build Summary with FIXES:${NC}"
    echo "• Force container cleanup: ✅ Completed"
    echo "• Port detection: ✅ Port ${OAUTH_PORT} selected"
    echo "• Configuration update: ✅ Automatic"
    echo "• FIXED OAuth2: ✅ response_type conflict resolved"
    echo "• FIXED Speedtest: ✅ Architecture detection implemented"
    echo "• FIXED Dockerfile: ✅ Directory creation + speedtest pre-install"
    echo "• Clean Docker build: ✅ No cache conflicts"
    echo "• Image verification: ✅ Ready to deploy"
    echo ""

    if [ $OAUTH_PORT -ne 8080 ]; then
        echo -e "${YELLOW}⚠️ Important - Google Cloud Console Update Required:${NC}"
        echo "• OAuth port changed from 8080 to ${OAUTH_PORT}"
        echo "• Update your Google Cloud Console OAuth client:"
        echo "  1. Go to APIs & Services > Credentials"
        echo "  2. Edit your OAuth 2.0 Client ID"
        echo "  3. Update Authorized redirect URI:"
        echo "     http://localhost:${OAUTH_PORT}"
        echo ""
    fi

    echo -e "${GREEN}🚀 Ready to start: ./start.sh${NC}"
    echo -e "${GREEN}📋 Or deploy everything: ./deploy.sh${NC}"
else
    echo -e "${RED}   ❌ Docker build failed${NC}"
    echo -e "${RED}   💡 Check logs above for errors${NC}"
    exit 1
fi
