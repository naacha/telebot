#!/bin/bash

# Container Restart Fix Tool untuk Bot OAuth2
# Mengatasi masalah container yang crash dan restart terus-menerus

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🔧 Container Restart Fix Tool${NC}"
echo -e "${CYAN}==============================${NC}"
echo ""

cd "$(dirname "$0")"

if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

CONTAINER_NAME=${CONTAINER_NAME:-"leech-bot"}

echo -e "${YELLOW}🔍 Diagnosing container restart issue...${NC}"

# Check container status
echo "📊 Container Status Check:"
if docker ps -a | grep -q ${CONTAINER_NAME}; then
    CONTAINER_STATUS=$(docker ps -a --format "table {{.Names}}\t{{.Status}}" | grep ${CONTAINER_NAME} | awk '{print $2" "$3" "$4" "$5}')
    echo "   Status: $CONTAINER_STATUS"
    
    if echo "$CONTAINER_STATUS" | grep -q "Restarting"; then
        echo -e "${RED}   ❌ Container is stuck in restart loop${NC}"
        RESTART_LOOP=true
    else
        echo -e "${GREEN}   ✅ Container status looks normal${NC}"
        RESTART_LOOP=false
    fi
else
    echo -e "${RED}   ❌ Container not found${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}🔍 Checking container logs for errors...${NC}"

# Get container logs
echo "📋 Recent Container Logs:"
echo "=========================="
docker logs ${CONTAINER_NAME} --tail=20 2>&1 | head -20

echo ""
echo -e "${BLUE}🔍 Checking for common issues...${NC}"

# Check 1: Environment variables
echo "1️⃣ Environment Variables Check:"
if [ -z "$BOT_TOKEN" ]; then
    echo -e "${RED}   ❌ BOT_TOKEN not set${NC}"
    ENV_ISSUE=true
else
    echo -e "${GREEN}   ✅ BOT_TOKEN configured${NC}"
    ENV_ISSUE=false
fi

if [ -z "$GOOGLE_CLIENT_ID" ]; then
    echo -e "${RED}   ❌ GOOGLE_CLIENT_ID not set${NC}"
    ENV_ISSUE=true
else
    echo -e "${GREEN}   ✅ GOOGLE_CLIENT_ID configured${NC}"
fi

if [ -z "$GOOGLE_CLIENT_SECRET" ]; then
    echo -e "${RED}   ❌ GOOGLE_CLIENT_SECRET not set${NC}"
    ENV_ISSUE=true
else
    echo -e "${GREEN}   ✅ GOOGLE_CLIENT_SECRET configured${NC}"
fi

# Check 2: Bot files
echo ""
echo "2️⃣ Bot Files Check:"
if [ -f "bot.py" ]; then
    echo -e "${GREEN}   ✅ bot.py exists${NC}"
    
    # Check for Python syntax errors
    if python3 -m py_compile bot.py 2>/dev/null; then
        echo -e "${GREEN}   ✅ bot.py syntax is valid${NC}"
    else
        echo -e "${RED}   ❌ bot.py has syntax errors${NC}"
        python3 -m py_compile bot.py
        SYNTAX_ERROR=true
    fi
else
    echo -e "${RED}   ❌ bot.py not found${NC}"
    FILE_ISSUE=true
fi

# Check 3: Docker image
echo ""
echo "3️⃣ Docker Image Check:"
if docker images | grep -q "bot-tele-3"; then
    echo -e "${GREEN}   ✅ Docker image exists${NC}"
    IMAGE_SIZE=$(docker images bot-tele-3:latest --format "{{.Size}}")
    echo "   Image size: $IMAGE_SIZE"
else
    echo -e "${RED}   ❌ Docker image not found${NC}"
    IMAGE_ISSUE=true
fi

echo ""
echo -e "${BLUE}🛠️ Applying fixes...${NC}"

# Fix 1: Stop problematic container
if [ "$RESTART_LOOP" = "true" ]; then
    echo "🛑 Stopping restart loop..."
    docker stop ${CONTAINER_NAME} 2>/dev/null || true
    docker rm ${CONTAINER_NAME} 2>/dev/null || true
    echo -e "${GREEN}   ✅ Container stopped and removed${NC}"
fi

# Fix 2: Environment issues
if [ "$ENV_ISSUE" = "true" ]; then
    echo "⚙️ Fixing environment configuration..."
    
    if [ ! -f ".env" ]; then
        echo "Creating .env from template..."
        cp .env.example .env
    fi
    
    echo ""
    echo -e "${YELLOW}❌ Missing environment variables detected!${NC}"
    echo "Please configure the following in .env file:"
    echo ""
    
    if [ -z "$BOT_TOKEN" ]; then
        echo "BOT_TOKEN=your-bot-token-from-botfather"
    fi
    
    if [ -z "$GOOGLE_CLIENT_ID" ]; then
        echo "GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com"
    fi
    
    if [ -z "$GOOGLE_CLIENT_SECRET" ]; then
        echo "GOOGLE_CLIENT_SECRET=GOCSPX-your-client-secret"
    fi
    
    echo ""
    echo "Edit .env file now:"
    echo "nano .env"
    echo ""
    echo "Then run this script again: ./container-fix.sh"
    exit 1
fi

# Fix 3: Create missing bot.py if needed
if [ ! -f "bot.py" ]; then
    echo "📝 Creating minimal bot.py for testing..."
    cat > bot.py << 'EOF'
#!/usr/bin/env python3
"""
Minimal OAuth2 Bot for Testing
"""

import os
import sys
import logging
from telegram.ext import Application

# Setup logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# Configuration
BOT_TOKEN = os.getenv('BOT_TOKEN')

def main():
    """Main function"""
    if not BOT_TOKEN:
        logger.error("❌ BOT_TOKEN not set in environment variables")
        sys.exit(1)
    
    logger.info("🚀 Starting minimal OAuth2 bot...")
    
    try:
        # Create bot application
        application = Application.builder().token(BOT_TOKEN).build()
        
        # Start bot
        logger.info("✅ Bot started successfully!")
        application.run_polling(drop_pending_updates=True)
        
    except Exception as e:
        logger.error(f"❌ Bot failed to start: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
EOF
    echo -e "${GREEN}   ✅ Minimal bot.py created${NC}"
fi

# Fix 4: Test environment and start container
echo ""
echo "🧪 Testing container start..."

# Create a test run to see immediate errors
echo "Running test container to check for immediate issues..."
TEST_OUTPUT=$(docker run --rm --env-file .env -v $(pwd)/bot.py:/app/bot.py:ro bot-tele-3:latest python /app/bot.py --help 2>&1 || echo "ERROR")

if echo "$TEST_OUTPUT" | grep -q "ERROR"; then
    echo -e "${RED}❌ Container test failed${NC}"
    echo "Error output:"
    echo "$TEST_OUTPUT"
    echo ""
    echo "🔧 Possible fixes:"
    echo "1. Rebuild image: ./build.sh"
    echo "2. Check Python syntax: python3 -c 'import bot'"
    echo "3. Check dependencies: pip install -r requirements.txt"
    exit 1
else
    echo -e "${GREEN}✅ Container test passed${NC}"
fi

# Start container with better error handling
echo ""
echo "🚀 Starting container with enhanced logging..."

docker run -d \
    --name ${CONTAINER_NAME} \
    --user root \
    --privileged \
    --restart unless-stopped \
    --env-file .env \
    -v $(pwd)/data:/app/data \
    -v $(pwd)/downloads:/app/downloads \
    -v $(pwd)/logs:/app/logs \
    -v $(pwd)/config:/app/config \
    -v /var/log/bot:/var/log/bot \
    -p 8080:8080 \
    bot-tele-3:latest

echo "⏳ Waiting for container to stabilize..."
sleep 10

# Check final status
echo ""
echo "🔍 Final Status Check:"
if docker ps | grep -q ${CONTAINER_NAME}; then
    FINAL_STATUS=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep ${CONTAINER_NAME})
    echo "   $FINAL_STATUS"
    
    if echo "$FINAL_STATUS" | grep -q "Up"; then
        echo -e "${GREEN}✅ Container is running successfully!${NC}"
        echo ""
        echo "📝 Next steps:"
        echo "   1. Check logs: ./logs.sh"
        echo "   2. Test bot: Send /start to bot in Telegram"
        echo "   3. Setup OAuth2: Send /auth in Telegram"
        echo ""
        echo "🔧 Monitoring commands:"
        echo "   ./status.sh     - Check status"
        echo "   ./logs.sh       - View logs"
        echo "   ./auth-test.sh  - Test OAuth2"
    else
        echo -e "${RED}❌ Container still having issues${NC}"
        echo ""
        echo "📋 View detailed logs:"
        echo "   docker logs ${CONTAINER_NAME} --tail=50"
        echo ""
        echo "🔧 Additional troubleshooting:"
        echo "   ./logs.sh       - Real-time logs"
        echo "   ./shell.sh      - Access container"
        echo "   ./restart.sh    - Restart container"
    fi
else
    echo -e "${RED}❌ Container failed to start${NC}"
    echo ""
    echo "📋 Check what went wrong:"
    echo "   docker logs ${CONTAINER_NAME}"
    echo ""
    echo "🔧 Possible fixes:"
    echo "   1. Check .env configuration"
    echo "   2. Rebuild image: ./build.sh"
    echo "   3. Check system resources: free -h && df -h"
fi

echo ""
echo "📞 Need help? Share logs with @Zalherathink"