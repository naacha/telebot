# STB HG680P Telegram Bot - Complete Edition

## 🚀 New Features Added

### ✅ Channel Subscription Protection
- **Required Channel:** @ZalheraThink  
- Users must join and stay subscribed
- Bot stops working if user leaves channel
- Automatic subscription verification

### ✅ Inline Commands Support
```
@yourbotusername help
@yourbotusername download https://example.com/file.zip
@yourbotusername system
```

### ✅ BotFather Commands Support
```
/d@yourbotusername https://example.com/file.zip
/help@yourbotusername
```

### ✅ Reply-to-Message Download
- Reply to any message containing a link
- Send `/d` to download the link from replied message

### ✅ Port Auto-Detection
- Automatically finds available ports (8080, 8081, 8082...)
- No more "port already allocated" errors
- Updates configuration automatically

### ✅ Docker Force Cleanup
- Prevents container conflicts
- Clean startup every time
- Removes orphaned containers

## 📋 Quick Deployment

### 1. Extract and Setup
```bash
unzip telegram-bot-stb-armbian-complete.zip
cd telegram-bot-stb-armbian-complete
sudo ./setup.sh  # Auto-stops existing Docker containers
```

### 2. Configuration
```bash
nano .env

# Required settings:
BOT_TOKEN=your_bot_token
BOT_USERNAME=your_bot_username_without_@
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret
```

### 3. Deploy
```bash
./start.sh  # Auto-detects available ports, force-stops old containers
```

## 🔧 BotFather Setup

### Commands to Set in @BotFather:
```
start - Start the bot and show welcome message
help - Show complete command help and usage examples  
auth - Connect Google Drive using CLI authentication method
d - Download file and upload to Google Drive
system - Show STB HG680P system information and stats
stats - Display bot statistics and user information
```

### Enable Inline Mode:
1. Go to @BotFather
2. Select your bot
3. Choose "Bot Settings" → "Inline Mode"
4. Enable inline mode
5. Set placeholder: "Type help, download [url], or system"

## 📢 Channel Setup

### Important: Channel ID Configuration
1. Add your bot to @ZalheraThink as admin
2. Get channel ID using @userinfobot
3. Update `CHANNEL_ID` in bot.py:
```python
CHANNEL_ID = -1001234567890  # Replace with actual ID
```

## 🎯 Usage Examples

### Standard Commands:
```
/start - Welcome message
/d https://example.com/file.zip - Download file
/auth - Connect Google Drive
/system - STB system info
```

### Inline Usage:
```
@yourbotusername help
@yourbotusername download https://files.com/video.mp4
@yourbotusername system
```

### BotFather Commands:
```
/d@yourbotusername https://example.com/document.pdf
/help@yourbotusername
```

### Reply Method:
1. Someone sends: "Check this file: https://example.com/file.zip"
2. Reply to that message with: `/d`
3. Bot extracts URL and downloads

## 🛠️ Troubleshooting

### Port Conflicts:
- Bot automatically finds available ports
- Starts from 8080, increments if busy
- Updates .env automatically

### Docker Conflicts:
- Run `./scripts/build.sh` for force cleanup
- All old containers removed before build

### Channel Issues:
1. Verify @ZalheraThink channel exists
2. Add bot as admin to channel
3. Get correct channel ID
4. Update CHANNEL_ID in bot.py

### Inline Not Working:
1. Enable inline mode in @BotFather
2. Set bot username in .env
3. Users must join @ZalheraThink first

## 📊 Management

### Commands:
```bash
./start.sh    # Start with port auto-detection
./stop.sh     # Stop bot
./restart.sh  # Full restart with cleanup
./logs.sh     # View live logs
./status.sh   # System status
./scripts/build.sh  # Force rebuild with cleanup
```

### Monitoring:
```bash
# Check port usage
netstat -tuln | grep :808

# Check containers
docker ps | grep telegram

# Check resources
htop
```

## 🔒 Security Features

- Channel subscription verification
- Owner-only admin commands
- Secure credential storage
- Docker container isolation
- Port conflict prevention

## ✅ All Issues Fixed

- ✅ OAuth2 Error 400 FIXED
- ✅ Port conflicts RESOLVED  
- ✅ Docker conflicts PREVENTED
- ✅ Channel subscription IMPLEMENTED
- ✅ Inline commands WORKING
- ✅ BotFather commands SUPPORTED
- ✅ Reply-to-message FUNCTIONAL
- ✅ ARM64 STB OPTIMIZED

**🎉 Complete solution for STB HG680P Armbian deployment!**
