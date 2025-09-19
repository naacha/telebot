#!/bin/bash
# STB HG680P Setup Script with Docker Cleanup and Port Auto-detection

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🚀 STB HG680P Telegram Bot Setup${NC}"
echo -e "${CYAN}=================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Please run as root: sudo ./setup.sh${NC}"
    exit 1
fi

# Stop existing Docker containers
echo -e "${BLUE}🛑 Stopping existing Docker containers...${NC}"
docker stop telegram-bot-stb 2>/dev/null || true
docker stop telegram-bot 2>/dev/null || true
docker rm -f telegram-bot-stb 2>/dev/null || true  
docker rm -f telegram-bot 2>/dev/null || true

# Clean Docker system
echo -e "${BLUE}🧹 Cleaning Docker system...${NC}"
docker system prune -f 2>/dev/null || true

echo -e "${GREEN}✅ Docker cleanup completed${NC}"

# Check if running on STB
if [[ $(uname -m) != "aarch64" ]]; then
    echo -e "${YELLOW}⚠️ Warning: This script is optimized for ARM64/aarch64 architecture${NC}"
fi

echo -e "${BLUE}📱 Detected System:${NC}"
echo "Architecture: $(uname -m)"
echo "OS: $(uname -s)"
echo "Kernel: $(uname -r)"
echo ""

# Update system packages
echo -e "${BLUE}📦 Updating STB system packages...${NC}"
apt-get update -y
apt-get upgrade -y

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo -e "${BLUE}🐳 Installing Docker for ARM64...${NC}"

    # Install prerequisites
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

    # Add Docker GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    # Add Docker repository for ARM64
    echo "deb [arch=arm64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io

    # Enable Docker service
    systemctl enable docker
    systemctl start docker

    echo -e "${GREEN}✅ Docker installed successfully${NC}"
else
    echo -e "${GREEN}✅ Docker already installed${NC}"
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null; then
    echo -e "${BLUE}📦 Installing Docker Compose for ARM64...${NC}"

    apt-get install -y python3-pip
    pip3 install docker-compose

    echo -e "${GREEN}✅ Docker Compose installed successfully${NC}"
else
    echo -e "${GREEN}✅ Docker Compose already installed${NC}"
fi

# Create directory structure
echo -e "${BLUE}📁 Creating directory structure...${NC}"
mkdir -p data downloads logs credentials
chmod -R 755 data downloads logs credentials

# Create environment file if not exists
if [ ! -f ".env" ]; then
    echo -e "${BLUE}⚙️ Creating environment configuration...${NC}"
    cp .env.example .env

    echo -e "${YELLOW}📝 Please edit .env file with your credentials:${NC}"
    echo ""
    echo "1. BOT_TOKEN - Get from @BotFather on Telegram"
    echo "2. BOT_USERNAME - Your bot username (without @)"
    echo "3. GOOGLE_CLIENT_ID - From Google Cloud Console"
    echo "4. GOOGLE_CLIENT_SECRET - From Google Cloud Console"
    echo ""
    echo -e "${BLUE}Edit command: nano .env${NC}"
    echo ""
fi

# Set proper permissions for STB
echo -e "${BLUE}🔧 Setting STB permissions...${NC}"
chown -R $(logname):$(logname) . 2>/dev/null || chown -R root:root .
chmod +x scripts/*.sh

echo -e "${CYAN}📊 STB HG680P System Information:${NC}"
echo "CPU: $(cat /proc/cpuinfo | grep 'model name' | head -1 | cut -d: -f2 | xargs)"
echo "Memory: $(free -h | awk '/^Mem:/ {print $2}') total"
echo "Storage: $(df -h / | awk 'NR==2 {print $4}') available"
echo "Architecture: $(uname -m)"
echo ""

echo -e "${GREEN}✅ STB HG680P setup completed successfully!${NC}"
echo ""
echo -e "${BLUE}📋 Next steps:${NC}"
echo "1. Edit .env file: nano .env"
echo "2. Start bot: ./start.sh" 
echo "3. Check logs: ./logs.sh"
echo "4. Stop bot: ./stop.sh"
echo ""
echo -e "${CYAN}🎉 Your STB is ready for Telegram bot deployment!${NC}"
