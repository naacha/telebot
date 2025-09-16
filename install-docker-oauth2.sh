#!/bin/bash

# OAuth2 Docker Installer (No credentials.json needed!)
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Welcome banner
clear
echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║           BOT-TELE-3 OAUTH2 INSTALLER                      ║"
echo "║     Speed Limited + Root Access + OAuth2 Client ID         ║"
echo "║                                                              ║"
echo "║   INSTALLS:                                                 ║"
echo "║   • Docker CE (Pure Docker, no Compose)                    ║"
echo "║   • OAuth2 authentication (no credentials.json!)           ║"
echo "║   • Speed limiting (5 MB/s per user)                       ║"
echo "║   • Concurrent limiting (2 per user)                       ║"
echo "║   • Auto cleanup system                                     ║"
echo "║   • Full ROOT access container                              ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ This script must be run as root${NC}"
    echo "Run: sudo ./install-docker-oauth2.sh"
    exit 1
fi

echo -e "${GREEN}✅ Running as root${NC}"

# System checks
echo -e "${BLUE}🔍 System checks...${NC}"

# Check space
AVAILABLE_GB=$(($(df / | awk 'NR==2 {print $4}') / 1024 / 1024))
if [ $AVAILABLE_GB -lt 2 ]; then
    echo -e "${RED}❌ Need at least 2GB free space. Available: ${AVAILABLE_GB}GB${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Disk space: ${AVAILABLE_GB}GB available${NC}"

# Check internet
if ! ping -c 3 google.com > /dev/null 2>&1; then
    echo -e "${RED}❌ No internet connection${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Internet connection verified${NC}"

# Update system
echo -e "${BLUE}🔄 Updating system...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt update
apt upgrade -y

# Install essentials
echo -e "${BLUE}📦 Installing essential packages...${NC}"
apt install -y curl wget git nano htop unzip gnupg lsb-release ca-certificates     software-properties-common apt-transport-https python3 python3-pip sqlite3

# Install Docker
echo -e "${BLUE}🐳 Installing Docker CE...${NC}"
apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo   "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian   $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
apt install -y docker-ce docker-ce-cli containerd.io

systemctl enable docker
systemctl start docker

if [ "$SUDO_USER" ]; then
    usermod -aG docker $SUDO_USER
fi

echo -e "${GREEN}✅ Docker installed${NC}"

# Test Docker
if docker run --rm hello-world > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Docker test passed${NC}"
else
    echo -e "${RED}❌ Docker test failed${NC}"
    exit 1
fi

# Configure Docker for STB
echo -e "${BLUE}⚡ Applying STB optimizations...${NC}"
mkdir -p /etc/docker

cat > /etc/docker/daemon.json << 'EOF'
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2",
    "live-restore": true,
    "userland-proxy": false,
    "max-concurrent-downloads": 3
}
EOF

if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
    echo 'vm.swappiness=10' >> /etc/sysctl.conf
    echo 'vm.dirty_ratio=5' >> /etc/sysctl.conf
fi

sysctl -p > /dev/null 2>&1
systemctl restart docker
sleep 3

echo -e "${GREEN}✅ STB optimizations applied${NC}"

# Create directories
echo -e "${BLUE}📁 Setting up directories...${NC}"
mkdir -p /opt/leech-bot-speed/{data,downloads,logs,config,backup}
chmod -R 755 /opt/leech-bot-speed

if [ "$SUDO_USER" ]; then
    chown -R $SUDO_USER:$SUDO_USER /opt/leech-bot-speed
fi

# Create systemd service
echo -e "${BLUE}🔧 Creating systemd service...${NC}"
cat > /etc/systemd/system/leech-bot.service << 'EOF'
[Unit]
Description=Telegram Leech Bot (OAuth2 + Root)
After=docker.service network-online.target
Requires=docker.service

[Service]
Type=forking
RemainAfterExit=yes
WorkingDirectory=/opt/leech-bot-speed
ExecStart=/opt/leech-bot-speed/start.sh
ExecStop=/opt/leech-bot-speed/stop.sh
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable leech-bot.service

# Installation complete
echo ""
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║        🎉 OAUTH2 INSTALLATION COMPLETED! 🎉               ║"
echo "║                                                              ║"
echo "║   Bot-Tele-3 with OAuth2 Client ID Authentication          ║"
echo "║   NO credentials.json file needed!                         ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo ""
echo -e "${YELLOW}📋 NEXT STEPS:${NC}"
echo ""
echo -e "${CYAN}1. Setup Google OAuth2:${NC}"
echo "   📖 Follow: OAUTH2-SETUP-GUIDE.md"
echo "   🔑 Get: GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET"
echo ""
echo -e "${CYAN}2. Configure environment:${NC}"
echo "   cd /opt/leech-bot-speed"
echo "   cp .env.example .env"
echo "   nano .env"
echo "   # Set BOT_TOKEN, GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET"
echo ""
echo -e "${CYAN}3. Deploy bot:${NC}"
echo "   ./build.sh"
echo "   ./start.sh"
echo ""
echo -e "${CYAN}4. Authenticate:${NC}"
echo "   # Send /auth to bot in Telegram"
echo "   # Complete OAuth2 flow"
echo ""
echo -e "${BLUE}🔑 OAUTH2 FEATURES:${NC}"
echo "   ✅ No credentials.json file needed"
echo "   ✅ Automatic token management"
echo "   ✅ Environment-based configuration"
echo "   ✅ Better security and deployment"
echo "   ✅ All speed limiting features maintained"
echo ""
echo -e "${GREEN}✨ Support: @Zalherathink${NC}"
echo "📖 OAuth2 Guide: OAUTH2-SETUP-GUIDE.md"
