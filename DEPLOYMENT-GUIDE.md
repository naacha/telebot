# Complete Deployment Guide

## 🚀 Quick Deployment

### Method 1: Automated (Recommended)
```bash
unzip telegram-bot-complete-fixed.zip -d /opt/telegram-bot
cd /opt/telegram-bot
chmod +x deploy.sh
sudo ./deploy.sh
```

### Method 2: Manual Steps
```bash
# 1. Configure environment
cp .env.example .env
nano .env

# 2. Build and deploy
docker build -t telegram-bot:latest .
./start.sh
```

## 📋 Configuration Steps

### 1. Google Cloud Setup
1. Create Google Cloud Project
2. Enable Google Drive API
3. Configure OAuth consent screen
4. Create **Web Application** OAuth client
5. Add redirect URI: http://localhost:8080

### 2. Bot Setup
1. Create bot with @BotFather
2. Copy bot token to .env
3. Set owner username to zalhera
4. Configure Google OAuth credentials

### 3. Deployment
1. Run deployment script
2. Test OAuth2 flow
3. Verify file downloads work

## ✅ Success Verification

- [ ] Bot responds to /start
- [ ] OAuth2 flow completes without errors
- [ ] File downloads and uploads work
- [ ] Owner commands function (@zalhera only)

## 🔧 Management

- `./status.sh` - Check bot status
- `./logs.sh` - View real-time logs
- `./restart.sh` - Restart bot
- `./fix-oauth2.sh` - Fix OAuth2 issues
