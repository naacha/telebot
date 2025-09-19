# STB HG680P Telegram Bot - Armbian 25.11

## 🚀 Overview
Complete Telegram bot optimized for STB HG680P running Armbian 25.11 CLI.
Designed specifically for ARM64 architecture with no GUI dependencies.

## 📱 STB Specifications
- **Device:** HG680P Set-Top Box
- **OS:** Armbian 25.11 (CLI only)
- **Architecture:** ARM64/aarch64
- **Memory:** Optimized for limited RAM
- **Storage:** Minimal disk usage

## 🛠️ Features
- ✅ OAuth2 Error 400 FIXED for CLI environment
- ✅ ARM64 optimized downloads
- ✅ Google Drive integration
- ✅ Docker Compose deployment
- ✅ CLI-only operation (no GUI needed)
- ✅ STB resource optimization
- ✅ 24/7 headless operation

## 📋 Quick Deployment

### 1. Prerequisites
```bash
# Ensure you're on STB with Armbian
cat /etc/armbian-release

# Check architecture
uname -m  # Should show aarch64
```

### 2. Extract and Setup
```bash
# Extract the bot package
unzip telegram-bot-stb-armbian-complete.zip
cd telegram-bot-stb-armbian-complete

# Run setup (installs Docker, Docker Compose)
sudo ./setup.sh
```

### 3. Configuration
```bash
# Edit environment variables
nano .env

# Required settings:
BOT_TOKEN=your_bot_token_from_botfather
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret
```

### 4. Start Bot
```bash
# Start the bot
./start.sh

# Check logs
./logs.sh

# Check status
./status.sh
```

## 🔧 Google Drive Setup (CLI Method)

### Step 1: Google Cloud Console
1. Go to Google Cloud Console > APIs & Services > Credentials
2. Create OAuth 2.0 Client ID
3. **Choose: Desktop Application** (not Web Application)
4. Add redirect URI: `http://localhost:8080`
5. Download credentials or copy Client ID/Secret

### Step 2: Bot Authentication
1. Start bot: `./start.sh`
2. In Telegram: `/start` then `/auth`
3. Open the provided link **on any device with browser**
4. Complete Google authentication
5. Copy the authorization code
6. In Telegram: `/code [authorization-code]`

## 📊 Management Commands

```bash
./start.sh    # Start bot
./stop.sh     # Stop bot
./restart.sh  # Restart bot
./logs.sh     # View logs
./status.sh   # System status
```

## 🔍 Troubleshooting

### Bot Won't Start
```bash
# Check Docker
sudo systemctl status docker

# Check configuration
cat .env

# Check logs
./logs.sh
```

### Google Drive Issues
```bash
# Check credentials in Telegram
/auth

# Verify environment variables
grep GOOGLE .env
```

### Resource Issues
```bash
# Check STB resources
./status.sh

# Free memory
sudo sync && echo 3 > /proc/sys/vm/drop_caches
```

## 📈 STB Optimization

### Memory Usage
- Container limit: 512MB
- Optimized for STB RAM constraints
- Automatic garbage collection

### CPU Usage
- ARM64 optimized code
- Async operations
- Limited concurrent downloads

### Storage Usage
- Automatic cleanup after upload
- Minimal local storage
- Log rotation

## 🌐 Network Configuration

### Port Usage
- 8080: Web interface/OAuth callback

### Firewall (if enabled)
```bash
sudo ufw allow 8080
```

## 🔧 Advanced Configuration

### Environment Variables
```env
MAX_CONCURRENT_DOWNLOADS=2    # Concurrent downloads
MAX_SPEED_MBPS=10            # Speed limit
CHUNK_SIZE=8192              # Download chunk size
```

### Docker Resources
```yaml
# In docker-compose.yml
resources:
  limits:
    memory: 512M
  reservations:
    memory: 256M
```

## 📱 STB Commands

### System Information
- `/system` - STB hardware info
- `/stats` - Bot statistics

### File Operations  
- `/d [link]` - Download and upload to Drive
- `/auth` - Connect Google Drive

## 🚀 Production Deployment

### Auto-start on Boot
```bash
# Create systemd service
sudo tee /etc/systemd/system/telegram-bot.service > /dev/null <<EOF
[Unit]
Description=STB Telegram Bot
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=true
WorkingDirectory=/home/$(logname)/telegram-bot-stb-armbian-complete
ExecStart=/bin/bash start.sh
ExecStop=/bin/bash stop.sh
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# Enable auto-start
sudo systemctl enable telegram-bot
sudo systemctl start telegram-bot
```

## 📋 Monitoring

### Health Checks
```bash
# Container health
docker-compose ps

# STB resources
htop

# Storage usage
df -h
```

### Logs
```bash
# Live logs
./logs.sh

# Specific container logs
docker-compose logs telegram-bot-stb
```

## 🎯 Tested Configurations

- ✅ STB HG680P with 2GB RAM
- ✅ Armbian 25.11 CLI
- ✅ Docker 24.x
- ✅ Docker Compose 2.x
- ✅ ARM64 architecture

## 🔒 Security

### File Permissions
```bash
# Set proper permissions
chmod 600 .env
chmod +x scripts/*.sh
```

### Container Security
- Non-root user inside container
- Limited resource access
- Secure token storage

## 💡 Tips for STB Usage

1. **Memory:** Keep concurrent downloads low (2-3 max)
2. **Storage:** Files are auto-deleted after upload
3. **Temperature:** Monitor STB temperature in summer
4. **Power:** Use UPS for stable operation
5. **Network:** Stable ethernet connection recommended

**🎉 Your STB HG680P is now ready for 24/7 Telegram bot operation!**
