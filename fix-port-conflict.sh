#!/bin/bash

# Port Conflict Fix Tool untuk Telegram Bot
# Mengatasi error "port is already allocated"

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🔧 Port Conflict Fix Tool${NC}"
echo -e "${CYAN}=======================${NC}"
echo ""

cd "$(dirname "$0")"

if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs) 2>/dev/null || true
fi

CONTAINER_NAME=${CONTAINER_NAME:-telegram-bot}
CONFLICT_PORT=8080

echo -e "${YELLOW}🔍 Diagnosing port conflict...${NC}"

# Check what's using port 8080
echo "📊 Checking port 8080 usage:"

# Method 1: netstat
if command -v netstat &> /dev/null; then
    PORT_INFO=$(netstat -tulpn 2>/dev/null | grep ":8080 ")
    if [ ! -z "$PORT_INFO" ]; then
        echo "Port 8080 is in use:"
        echo "$PORT_INFO"
    fi
fi

# Method 2: lsof
if command -v lsof &> /dev/null; then
    LSOF_INFO=$(lsof -i :8080 2>/dev/null || echo "")
    if [ ! -z "$LSOF_INFO" ]; then
        echo "lsof output for port 8080:"
        echo "$LSOF_INFO"
    fi
fi

# Method 3: ss command
if command -v ss &> /dev/null; then
    SS_INFO=$(ss -tulpn | grep ":8080 " || echo "")
    if [ ! -z "$SS_INFO" ]; then
        echo "ss output for port 8080:"
        echo "$SS_INFO"
    fi
fi

# Check for Docker containers using port 8080
echo ""
echo "📋 Docker containers using port 8080:"
DOCKER_CONTAINERS=$(docker ps --format "table {{.Names}}\t{{.Ports}}" | grep "8080" || echo "None found")
echo "$DOCKER_CONTAINERS"

echo ""
echo -e "${BLUE}🛠️ Applying port conflict fixes...${NC}"

# Fix 1: Stop and remove existing containers using port 8080
echo "1️⃣ Stopping containers using port 8080..."

# Get container IDs using port 8080
CONTAINERS_USING_PORT=$(docker ps -q --filter "publish=8080")

if [ ! -z "$CONTAINERS_USING_PORT" ]; then
    echo "Found containers using port 8080:"
    docker ps --filter "publish=8080" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    for container in $CONTAINERS_USING_PORT; do
        CONTAINER_NAME_FOUND=$(docker ps --filter "id=$container" --format "{{.Names}}")
        echo "Stopping container: $CONTAINER_NAME_FOUND"
        docker stop $container 2>/dev/null || true
        docker rm $container 2>/dev/null || true
    done
    echo -e "${GREEN}   ✅ Stopped conflicting containers${NC}"
else
    echo "   ℹ️ No Docker containers found using port 8080"
fi

# Fix 2: Check for system processes
echo ""
echo "2️⃣ Checking for system processes using port 8080..."

if command -v lsof &> /dev/null; then
    SYSTEM_PROCESSES=$(lsof -ti :8080 2>/dev/null || echo "")
    if [ ! -z "$SYSTEM_PROCESSES" ]; then
        echo "Found system processes using port 8080:"
        lsof -i :8080 2>/dev/null || true
        
        echo ""
        echo -e "${YELLOW}⚠️ System processes are using port 8080${NC}"
        echo "Options:"
        echo "a) Kill processes (risky): sudo kill $SYSTEM_PROCESSES"
        echo "b) Use different port (recommended)"
        echo ""
        read -p "Kill processes? (y/N): " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Killing processes: $SYSTEM_PROCESSES"
            sudo kill $SYSTEM_PROCESSES 2>/dev/null || true
            sleep 2
            echo -e "${GREEN}   ✅ Processes killed${NC}"
        else
            echo "   ℹ️ Keeping processes, will use alternative port"
        fi
    else
        echo "   ✅ No system processes using port 8080"
    fi
fi

# Fix 3: Determine best port to use
echo ""
echo "3️⃣ Finding available port..."

# Function to check if port is available
is_port_available() {
    local port=$1
    ! (netstat -tuln 2>/dev/null | grep -q ":$port " || lsof -i :$port >/dev/null 2>&1)
}

# Try to find available port
AVAILABLE_PORT=8080
if is_port_available 8080; then
    echo "   ✅ Port 8080 is now available"
    AVAILABLE_PORT=8080
else
    echo "   ⚠️ Port 8080 still occupied, finding alternative..."
    
    # Try alternative ports
    for port in 8081 8082 8083 8084 8085 8090 8091 8092; do
        if is_port_available $port; then
            AVAILABLE_PORT=$port
            echo "   ✅ Found available port: $port"
            break
        fi
    done
fi

# Fix 4: Update configuration if needed
if [ "$AVAILABLE_PORT" != "8080" ]; then
    echo ""
    echo "4️⃣ Updating configuration for port $AVAILABLE_PORT..."
    
    # Update .env file
    if [ -f ".env" ]; then
        # Backup original
        cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
        
        # Update or add port configuration
        if grep -q "OAUTH_PORT=" .env; then
            sed -i "s/OAUTH_PORT=.*/OAUTH_PORT=$AVAILABLE_PORT/" .env
        else
            echo "OAUTH_PORT=$AVAILABLE_PORT" >> .env
        fi
        
        # Update redirect URI if needed
        if grep -q "GOOGLE_REDIRECT_URI=" .env; then
            sed -i "s|GOOGLE_REDIRECT_URI=.*|GOOGLE_REDIRECT_URI=http://localhost:$AVAILABLE_PORT|" .env
        else
            echo "GOOGLE_REDIRECT_URI=http://localhost:$AVAILABLE_PORT" >> .env
        fi
        
        echo -e "${GREEN}   ✅ Configuration updated to use port $AVAILABLE_PORT${NC}"
        echo "   📝 .env backup created"
    fi
    
    echo ""
    echo -e "${YELLOW}⚠️ IMPORTANT: Update Google Cloud Console${NC}"
    echo "Update OAuth2 Redirect URI to: http://localhost:$AVAILABLE_PORT"
    echo "1. Go to Google Cloud Console"
    echo "2. APIs & Services > Credentials"
    echo "3. Edit your OAuth 2.0 Client"
    echo "4. Add redirect URI: http://localhost:$AVAILABLE_PORT"
fi

# Fix 5: Create fixed start script
echo ""
echo "5️⃣ Creating fixed start script..."

cat > start-fixed.sh << EOF
#!/bin/bash

# Fixed Start Script with Port Resolution
cd "\$(dirname "\$0")"

if [ -f ".env" ]; then
    export \$(cat .env | grep -v '^#' | xargs) 2>/dev/null || true
fi

CONTAINER_NAME=\${CONTAINER_NAME:-telegram-bot}
IMAGE_NAME=\${IMAGE_NAME:-telegram-bot:latest}
OAUTH_PORT=\${OAUTH_PORT:-$AVAILABLE_PORT}

echo "🚀 Starting Telegram Bot (Port: \$OAUTH_PORT)..."

# Stop existing container
if docker ps -q -f name=\${CONTAINER_NAME} > /dev/null; then
    echo "🛑 Stopping existing container..."
    docker stop \${CONTAINER_NAME}
fi

if docker ps -aq -f name=\${CONTAINER_NAME} > /dev/null; then
    echo "🗑️ Removing existing container..."
    docker rm \${CONTAINER_NAME}
fi

# Start with correct port
echo "🔄 Starting container on port \$OAUTH_PORT..."

docker run -d \\
    --name \${CONTAINER_NAME} \\
    --user root \\
    --restart unless-stopped \\
    --env-file .env \\
    -v \$(pwd)/data:/app/data \\
    -v \$(pwd)/downloads:/app/downloads \\
    -v \$(pwd)/logs:/app/logs \\
    -p \${OAUTH_PORT}:8080 \\
    \${IMAGE_NAME}

sleep 3

if docker ps -q -f name=\${CONTAINER_NAME} > /dev/null; then
    echo "✅ Bot started successfully on port \$OAUTH_PORT!"
    echo "📋 OAuth2 will use: http://localhost:\$OAUTH_PORT"
    echo "🔧 Management: ./status.sh, ./logs.sh"
else
    echo "❌ Failed to start"
    docker logs \${CONTAINER_NAME}
fi
EOF

chmod +x start-fixed.sh

echo -e "${GREEN}   ✅ Created start-fixed.sh${NC}"

# Fix 6: Test the fix
echo ""
echo "6️⃣ Testing the fix..."

if is_port_available $AVAILABLE_PORT; then
    echo -e "${GREEN}   ✅ Port $AVAILABLE_PORT is available for use${NC}"
    
    echo ""
    echo -e "${BLUE}🚀 Ready to start bot with fixed port${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Update Google Cloud Console redirect URI (if port changed)"
    echo "2. Start bot: ./start-fixed.sh"
    echo "3. Test OAuth2 flow"
    echo ""
    echo "Or start immediately:"
    read -p "Start bot now? (Y/n): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo "🚀 Starting bot with fixed configuration..."
        ./start-fixed.sh
    fi
else
    echo -e "${RED}   ❌ Port $AVAILABLE_PORT is still not available${NC}"
    echo ""
    echo "Manual steps required:"
    echo "1. Check what's using the port: lsof -i :$AVAILABLE_PORT"
    echo "2. Stop the conflicting service"
    echo "3. Run this fix tool again"
fi

echo ""
echo -e "${CYAN}📋 Port Conflict Resolution Summary:${NC}"
echo "• Checked and stopped conflicting Docker containers"
echo "• Identified available port: $AVAILABLE_PORT"
if [ "$AVAILABLE_PORT" != "8080" ]; then
    echo "• Updated configuration to use port $AVAILABLE_PORT"
    echo "• Created start-fixed.sh script"
    echo ""
    echo -e "${YELLOW}⚠️ Remember to update Google Cloud Console redirect URI!${NC}"
    echo "   New URI: http://localhost:$AVAILABLE_PORT"
fi

echo ""
echo -e "${GREEN}🎉 Port conflict fix completed!${NC}"