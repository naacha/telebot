#!/bin/bash

# Docker Build Fix Tool untuk Bot-Tele-3 OAuth2
# Mengatasi build errors di STB HG680P ARM architecture

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🔧 Docker Build Fix Tool${NC}"
echo -e "${CYAN}========================${NC}"
echo ""

cd "$(dirname "$0")"

if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

IMAGE_NAME=${IMAGE_NAME:-"bot-tele-3:latest"}

echo -e "${YELLOW}🔍 Diagnosing build issues...${NC}"

# Check system architecture
ARCH=$(uname -m)
echo "📊 Architecture: $ARCH"

# Check available space
SPACE_GB=$(($(df . | awk 'NR==2 {print $4}') / 1024 / 1024))
echo "💾 Available space: ${SPACE_GB}GB"

# Check internet connectivity
if ping -c 1 google.com > /dev/null 2>&1; then
    echo "🌐 Internet: ✅ OK"
else
    echo "🌐 Internet: ❌ Failed"
    echo -e "${RED}❌ No internet connection. Check network settings.${NC}"
    exit 1
fi

# Check Docker status
if systemctl is-active docker > /dev/null 2>&1; then
    echo "🐳 Docker: ✅ Running"
else
    echo "🐳 Docker: ❌ Not running"
    echo -e "${YELLOW}🔄 Starting Docker...${NC}"
    sudo systemctl start docker
    sleep 3
fi

echo ""
echo -e "${BLUE}🛠️ Applying build fixes...${NC}"

# Fix 1: Clean Docker cache
echo "🧹 Cleaning Docker build cache..."
docker builder prune -f > /dev/null 2>&1 || true

# Fix 2: Update requirements.txt dengan versi ARM-compatible
echo "📦 Creating ARM-compatible requirements..."
cat > requirements.txt << 'EOF'
# ARM-Compatible Requirements for STB HG680P
# Core Telegram Bot (tested on ARM)
python-telegram-bot==20.7
requests==2.31.0
aiohttp==3.8.6

# Google OAuth2 (ARM compatible versions)
google-auth==2.23.4
google-auth-oauthlib==1.0.0
google-auth-httplib2==0.1.1
google-api-python-client==2.103.0

# Utilities (ARM tested)
humanize==4.8.0
tqdm==4.66.1
psutil==5.9.6
EOF

# Fix 3: Create fixed Dockerfile
echo "🔨 Creating ARM-optimized Dockerfile..."
cat > Dockerfile << 'EOF'
# Use Python 3.11 Alpine for ARM compatibility
FROM python:3.11-alpine

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONPATH=/app
ENV PYTHONIOENCODING=utf-8

# Install system dependencies (ARM-optimized)
RUN apk add --no-cache \
    gcc \
    g++ \
    musl-dev \
    linux-headers \
    libffi-dev \
    openssl-dev \
    curl \
    wget \
    git \
    sqlite \
    sudo \
    bash \
    nano \
    htop \
    procps \
    shadow \
    util-linux \
    coreutils \
    findutils \
    ca-certificates \
    tzdata \
    && rm -rf /var/cache/apk/*

# Create app directory
WORKDIR /app

# Create required directories
RUN mkdir -p /app/{data,downloads,logs,config,backup} \
    && mkdir -p /var/log/bot \
    && mkdir -p /var/run/bot

# Copy requirements first for better caching
COPY requirements.txt /app/

# Upgrade pip first
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

# Install Python dependencies in stages to handle ARM issues
RUN pip install --no-cache-dir requests==2.31.0 \
    && pip install --no-cache-dir aiohttp==3.8.6 \
    && pip install --no-cache-dir python-telegram-bot==20.7

# Install Google OAuth2 dependencies
RUN pip install --no-cache-dir google-auth==2.23.4 \
    && pip install --no-cache-dir google-auth-oauthlib==1.0.0 \
    && pip install --no-cache-dir google-auth-httplib2==0.1.1 \
    && pip install --no-cache-dir google-api-python-client==2.103.0

# Install utilities
RUN pip install --no-cache-dir humanize==4.8.0 tqdm==4.66.1 psutil==5.9.6

# Copy application files
COPY bot.py /app/
COPY system-manager.sh /app/
COPY cleanup.sh /app/
COPY healthcheck.sh /app/

# Make scripts executable
RUN chmod +x /app/*.sh

# Set permissions
RUN chmod -R 777 /app \
    && chmod -R 755 /var/log/bot \
    && chmod -R 755 /var/run/bot

# Create user with sudo access
RUN adduser -D -s /bin/bash botuser \
    && echo "botuser ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD python -c "import requests; print('OK')" || exit 1

# Expose port for OAuth2 callback
EXPOSE 8080

# Set working directory
WORKDIR /app

# Default user (overridden with --user root)
USER botuser

# Entry point
CMD ["python", "/app/bot.py"]
EOF

# Fix 4: Create missing system scripts if they don't exist
if [ ! -f "system-manager.sh" ]; then
    echo "📝 Creating system-manager.sh..."
    cat > system-manager.sh << 'EOF'
#!/bin/bash
# System Manager Script
echo "System Manager (OAuth2 Mode)"
case "$1" in
    status)
        echo "System Status:"
        whoami
        id
        df -h
        free -h
        ;;
    *)
        echo "Usage: $0 {status}"
        ;;
esac
EOF
    chmod +x system-manager.sh
fi

if [ ! -f "cleanup.sh" ]; then
    echo "📝 Creating cleanup.sh..."
    cat > cleanup.sh << 'EOF'
#!/bin/bash
# Cleanup Script
echo "Cleanup operations"
find /app/downloads -type f -mtime +1 -delete 2>/dev/null || true
EOF
    chmod +x cleanup.sh
fi

if [ ! -f "healthcheck.sh" ]; then
    echo "📝 Creating healthcheck.sh..."
    cat > healthcheck.sh << 'EOF'
#!/bin/bash
# Health Check Script
python -c "import requests; print('OK')" 2>/dev/null || exit 1
EOF
    chmod +x healthcheck.sh
fi

echo ""
echo -e "${BLUE}🔨 Attempting fixed build...${NC}"
echo "Building image: ${IMAGE_NAME}"
echo "This may take 5-10 minutes on ARM devices..."
echo ""

# Build with verbose output and better error handling
if docker build --no-cache -t ${IMAGE_NAME} . 2>&1 | tee build.log; then
    echo ""
    echo -e "${GREEN}✅ Build successful with fixes!${NC}"
    echo "🖼️ Image: ${IMAGE_NAME}"
    echo "💾 Size: $(docker images ${IMAGE_NAME} --format '{{.Size}}')"
    echo ""
    echo "🚀 Ready to start: ./start.sh"
    
    # Clean up build log on success
    rm -f build.log
else
    echo ""
    echo -e "${RED}❌ Build still failed. Checking logs...${NC}"
    
    if [ -f "build.log" ]; then
        echo ""
        echo -e "${YELLOW}📋 Build error details:${NC}"
        echo "----------------------------------------"
        tail -20 build.log
        echo "----------------------------------------"
        echo ""
    fi
    
    echo -e "${YELLOW}🔧 Additional troubleshooting options:${NC}"
    echo ""
    echo "1️⃣ Try different Python version:"
    echo "   sed -i 's/python:3.11-alpine/python:3.10-alpine/' Dockerfile"
    echo "   docker build -t ${IMAGE_NAME} ."
    echo ""
    echo "2️⃣ Use Ubuntu base instead of Alpine:"
    echo "   ./build-ubuntu.sh"
    echo ""
    echo "3️⃣ Build individual packages:"
    echo "   ./build-minimal.sh"
    echo ""
    echo "4️⃣ Check system resources:"
    echo "   free -h"
    echo "   df -h"
    echo ""
    echo "5️⃣ Restart Docker daemon:"
    echo "   sudo systemctl restart docker"
    echo "   ./build-fix.sh"
    echo ""
    echo "📞 Need help? Save build.log and contact @Zalherathink"
    
    exit 1
fi