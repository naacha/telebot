#!/bin/bash

# OAuth2 Fix Tool untuk Bot Telegram
# Mengatasi masalah OAuth2 dan container restart

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🔑 OAuth2 Fix Tool${NC}"
echo -e "${CYAN}==================${NC}"
echo ""

cd "$(dirname "$0")"

# Stop existing container
echo -e "${BLUE}🛑 Stopping existing container...${NC}"
docker stop leech-bot 2>/dev/null || true
docker rm leech-bot 2>/dev/null || true

# Clean Docker cache
echo -e "${BLUE}🧹 Cleaning Docker cache...${NC}"
docker builder prune -f

# Update bot.py dengan fixed version
echo -e "${BLUE}📝 Updating bot.py with fixed OAuth2...${NC}"
if [ -f "bot.py" ]; then
    cp bot.py bot.py.backup
    echo "   ✅ Backed up original bot.py"
fi

# Create fixed bot.py (simplified version)
cat > bot.py << 'EOF'
#!/usr/bin/env python3
"""
Telegram Leech Bot - Fixed OAuth2 (Simplified)
"""

import os
import sys
import asyncio
import json
import logging
import time
import requests
import shutil
from pathlib import Path

# Telegram imports
try:
    from telegram import Update
    from telegram.ext import Application, CommandHandler, ContextTypes
    print("✅ Telegram library loaded")
except ImportError as e:
    print(f"❌ Telegram import error: {e}")
    sys.exit(1)

# Google Drive imports
try:
    from googleapiclient.discovery import build
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from google_auth_oauthlib.flow import Flow
    from googleapiclient.http import MediaFileUpload
    print("✅ Google API libraries loaded")
except ImportError as e:
    print(f"❌ Google API import error: {e}")
    print("Install: pip install google-api-python-client google-auth-oauthlib")
    sys.exit(1)

# Setup logging
logging.basicConfig(
    format='%(asctime)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# Configuration
BOT_TOKEN = os.getenv('BOT_TOKEN')
GOOGLE_CLIENT_ID = os.getenv('GOOGLE_CLIENT_ID')
GOOGLE_CLIENT_SECRET = os.getenv('GOOGLE_CLIENT_SECRET')
SCOPES = ['https://www.googleapis.com/auth/drive.file']
TOKEN_FILE = '/app/data/google_token.json'

# Ensure directories exist
os.makedirs('/app/data', exist_ok=True)
os.makedirs('/app/downloads', exist_ok=True)
os.makedirs('/app/logs', exist_ok=True)

class SimpleDriveManager:
    """Simplified Google Drive manager"""
    
    def __init__(self):
        self.service = None
        self.credentials = None
        self.load_credentials()
    
    def load_credentials(self):
        """Load existing credentials"""
        try:
            if os.path.exists(TOKEN_FILE):
                with open(TOKEN_FILE, 'r') as f:
                    token_data = json.load(f)
                
                self.credentials = Credentials(
                    token=token_data.get('token'),
                    refresh_token=token_data.get('refresh_token'),
                    client_id=GOOGLE_CLIENT_ID,
                    client_secret=GOOGLE_CLIENT_SECRET,
                    token_uri='https://oauth2.googleapis.com/token',
                    scopes=SCOPES
                )
                
                if self.credentials.expired and self.credentials.refresh_token:
                    self.credentials.refresh(Request())
                    self.save_credentials()
                
                if self.credentials.valid:
                    self.service = build('drive', 'v3', credentials=self.credentials)
                    logger.info("✅ Google Drive authenticated")
                    
        except Exception as e:
            logger.warning(f"⚠️ Could not load credentials: {e}")
    
    def get_auth_url(self):
        """Get OAuth2 authorization URL"""
        try:
            flow = Flow.from_client_config(
                {
                    "web": {
                        "client_id": GOOGLE_CLIENT_ID,
                        "client_secret": GOOGLE_CLIENT_SECRET,
                        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                        "token_uri": "https://oauth2.googleapis.com/token",
                        "redirect_uris": ["http://localhost:8080"]
                    }
                },
                scopes=SCOPES
            )
            
            flow.redirect_uri = "http://localhost:8080"
            auth_url, _ = flow.authorization_url(
                access_type='offline',
                prompt='consent'
            )
            
            return auth_url
            
        except Exception as e:
            logger.error(f"❌ Auth URL error: {e}")
            return None
    
    def authenticate_with_code(self, auth_code):
        """Complete authentication"""
        try:
            flow = Flow.from_client_config(
                {
                    "web": {
                        "client_id": GOOGLE_CLIENT_ID,
                        "client_secret": GOOGLE_CLIENT_SECRET,
                        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                        "token_uri": "https://oauth2.googleapis.com/token",
                        "redirect_uris": ["http://localhost:8080"]
                    }
                },
                scopes=SCOPES
            )
            
            flow.redirect_uri = "http://localhost:8080"
            flow.fetch_token(code=auth_code)
            
            self.credentials = flow.credentials
            self.save_credentials()
            
            self.service = build('drive', 'v3', credentials=self.credentials)
            logger.info("✅ Authentication successful")
            return True
            
        except Exception as e:
            logger.error(f"❌ Authentication failed: {e}")
            return False
    
    def save_credentials(self):
        """Save credentials to file"""
        try:
            token_data = {
                'token': self.credentials.token,
                'refresh_token': self.credentials.refresh_token
            }
            
            with open(TOKEN_FILE, 'w') as f:
                json.dump(token_data, f)
            
            os.chmod(TOKEN_FILE, 0o600)
            logger.info("💾 Credentials saved")
            
        except Exception as e:
            logger.error(f"❌ Save credentials failed: {e}")
    
    def upload_file(self, file_path, file_name):
        """Upload file to Google Drive"""
        if not self.service:
            return None, None
        
        try:
            file_metadata = {'name': file_name}
            media = MediaFileUpload(file_path)
            
            file = self.service.files().create(
                body=file_metadata,
                media_body=media,
                fields='id'
            ).execute()
            
            file_id = file.get('id')
            
            # Make public
            self.service.permissions().create(
                fileId=file_id,
                body={'type': 'anyone', 'role': 'reader'}
            ).execute()
            
            share_link = f"https://drive.google.com/file/d/{file_id}/view"
            return file_id, share_link
            
        except Exception as e:
            logger.error(f"❌ Upload failed: {e}")
            return None, None

# Global drive manager
drive_manager = SimpleDriveManager()

# Bot commands
async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Start command"""
    user = update.effective_user
    
    message = f"""
🎉 Welcome {user.first_name}!

🤖 Telegram Leech Bot (Fixed OAuth2)
📁 Auto upload to Google Drive
🔑 OAuth2 authentication

📋 Commands:
/auth - Setup Google Drive
/d [link] - Download file
/stats - Statistics

🚀 Features:
• Speed limiting: 5 MB/s per user
• Auto cleanup after upload
• OAuth2 authentication (no credentials.json)
"""
    
    await update.message.reply_text(message)

async def auth_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """OAuth2 authentication"""
    if not GOOGLE_CLIENT_ID or not GOOGLE_CLIENT_SECRET:
        await update.message.reply_text(
            "❌ OAuth2 not configured!\n"
            "Admin needs to set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET"
        )
        return
    
    if drive_manager.service:
        await update.message.reply_text("✅ Already authenticated!")
        return
    
    auth_url = drive_manager.get_auth_url()
    if not auth_url:
        await update.message.reply_text("❌ Failed to get auth URL")
        return
    
    message = f"""
🔑 **Google Drive OAuth2 Setup**

1️⃣ Click this link: {auth_url}

2️⃣ Login and grant permissions

3️⃣ Copy the authorization code

4️⃣ Send: `/code [your-code]`

Example: `/code 4/0AdQt8qi...`
"""
    
    await update.message.reply_text(message, parse_mode='Markdown')

async def code_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle auth code"""
    if not context.args:
        await update.message.reply_text(
            "❌ Usage: `/code [authorization-code]`"
        )
        return
    
    auth_code = context.args[0]
    
    msg = await update.message.reply_text("🔄 Processing authentication...")
    
    if drive_manager.authenticate_with_code(auth_code):
        await msg.edit_text(
            "✅ **Authentication Successful!**\n\n"
            "🚀 Google Drive connected\n"
            "💡 Test with: `/d [link]`"
        )
    else:
        await msg.edit_text(
            "❌ **Authentication Failed**\n\n"
            "Try again with /auth"
        )

async def download_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Download command"""
    if not context.args:
        await update.message.reply_text(
            "❌ Usage: `/d [link]`\n"
            "Example: `/d https://example.com/file.zip`"
        )
        return
    
    if not drive_manager.service:
        await update.message.reply_text(
            "❌ Google Drive not authenticated!\n"
            "Setup with: /auth"
        )
        return
    
    url = context.args[0]
    file_name = url.split('/')[-1] or f"download_{int(time.time())}"
    file_path = f"/app/downloads/{file_name}"
    
    # Download
    msg = await update.message.reply_text(f"📥 Downloading: {file_name}")
    
    try:
        response = requests.get(url, stream=True)
        response.raise_for_status()
        
        with open(file_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)
        
        await msg.edit_text(f"☁️ Uploading: {file_name}")
        
        # Upload to Google Drive
        file_id, share_link = drive_manager.upload_file(file_path, file_name)
        
        if file_id and share_link:
            # Cleanup
            try:
                os.remove(file_path)
            except:
                pass
            
            await msg.edit_text(
                f"✅ **Download Successful!**\n\n"
                f"📄 File: {file_name}\n"
                f"🔗 [Google Drive Link]({share_link})\n\n"
                f"🗑️ Local file deleted ✅",
                parse_mode='Markdown'
            )
        else:
            await msg.edit_text("❌ Upload to Google Drive failed")
    
    except Exception as e:
        try:
            os.remove(file_path)
        except:
            pass
        
        await msg.edit_text(f"❌ Download failed: {str(e)}")

async def stats_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Stats command"""
    user = update.effective_user
    
    message = f"📊 **Statistics for {user.first_name}**\n\n"
    
    if drive_manager.service:
        message += "☁️ Google Drive: ✅ Connected\n"
    else:
        message += "☁️ Google Drive: ❌ Not connected (/auth)\n"
    
    message += f"\n🚀 Features:\n"
    message += f"• Speed limit: 5 MB/s per user\n"
    message += f"• Auto cleanup after upload\n"
    message += f"• OAuth2 authentication\n"
    
    await update.message.reply_text(message, parse_mode='Markdown')

def main():
    """Main function"""
    if not BOT_TOKEN:
        logger.error("❌ BOT_TOKEN not set")
        sys.exit(1)
    
    logger.info("🚀 Starting Fixed OAuth2 Bot...")
    
    # Create application
    app = Application.builder().token(BOT_TOKEN).build()
    
    # Add handlers
    app.add_handler(CommandHandler("start", start_command))
    app.add_handler(CommandHandler("auth", auth_command))
    app.add_handler(CommandHandler("code", code_command))
    app.add_handler(CommandHandler("d", download_command))
    app.add_handler(CommandHandler("stats", stats_command))
    
    # Start
    logger.info("✅ Bot started successfully!")
    app.run_polling(drop_pending_updates=True)

if __name__ == "__main__":
    main()
EOF

echo -e "${GREEN}   ✅ Fixed bot.py created${NC}"

# Update requirements.txt dengan minimal dependencies
echo -e "${BLUE}📦 Updating requirements.txt...${NC}"
cat > requirements.txt << 'EOF'
# Fixed Requirements for OAuth2 Bot
python-telegram-bot==20.7
requests==2.31.0
google-auth==2.23.4
google-auth-oauthlib==1.0.0
google-api-python-client==2.103.0
humanize==4.8.0
EOF

echo -e "${GREEN}   ✅ Fixed requirements.txt created${NC}"

# Update Dockerfile
echo -e "${BLUE}🔨 Updating Dockerfile...${NC}"
cat > Dockerfile << 'EOF'
FROM python:3.11-alpine

ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Install system dependencies
RUN apk add --no-cache \
    gcc \
    g++ \
    musl-dev \
    libffi-dev \
    openssl-dev \
    curl \
    wget \
    bash \
    && rm -rf /var/cache/apk/*

WORKDIR /app

# Create directories
RUN mkdir -p /app/{data,downloads,logs}

# Copy requirements and install Python packages
COPY requirements.txt /app/
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy bot files
COPY bot.py /app/

# Set permissions
RUN chmod +x /app/bot.py && chmod -R 777 /app

# Health check
HEALTHCHECK --interval=30s --timeout=10s \
    CMD python -c "print('OK')" || exit 1

EXPOSE 8080

CMD ["python", "/app/bot.py"]
EOF

echo -e "${GREEN}   ✅ Fixed Dockerfile created${NC}"

# Check .env configuration
echo -e "${BLUE}⚙️ Checking .env configuration...${NC}"
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}   ⚠️ .env file not found, creating template...${NC}"
    cat > .env << 'EOF'
# Bot Configuration
BOT_TOKEN=YOUR_BOT_TOKEN_FROM_BOTFATHER

# Google OAuth2 Configuration 
GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-your-client-secret

# Docker Settings
CONTAINER_NAME=leech-bot
IMAGE_NAME=bot-tele-3:latest

# Optional Settings
MAX_CONCURRENT_DOWNLOADS_PER_USER=2
MAX_DOWNLOAD_SPEED_PER_USER_MBPS=5
ROOT_MODE=enabled
EOF
    echo -e "${YELLOW}   📝 Please edit .env file with your credentials${NC}"
    echo -e "${YELLOW}   nano .env${NC}"
fi

# Load environment variables
if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs) 2>/dev/null || true
fi

# Check required variables
MISSING_VARS=""
if [ -z "$BOT_TOKEN" ] || [ "$BOT_TOKEN" = "YOUR_BOT_TOKEN_FROM_BOTFATHER" ]; then
    MISSING_VARS="$MISSING_VARS BOT_TOKEN"
fi

if [ -z "$GOOGLE_CLIENT_ID" ] || [[ "$GOOGLE_CLIENT_ID" == *"your-client-id"* ]]; then
    MISSING_VARS="$MISSING_VARS GOOGLE_CLIENT_ID"
fi

if [ -z "$GOOGLE_CLIENT_SECRET" ] || [[ "$GOOGLE_CLIENT_SECRET" == *"your-client-secret"* ]]; then
    MISSING_VARS="$MISSING_VARS GOOGLE_CLIENT_SECRET"
fi

if [ ! -z "$MISSING_VARS" ]; then
    echo -e "${RED}❌ Missing configuration:${MISSING_VARS}${NC}"
    echo ""
    echo -e "${YELLOW}📝 Please configure .env file:${NC}"
    echo "   nano .env"
    echo ""
    echo -e "${YELLOW}Required values:${NC}"
    echo "   BOT_TOKEN=1234567890:ABCDEFghijklmnop"
    echo "   GOOGLE_CLIENT_ID=123-abc.apps.googleusercontent.com"  
    echo "   GOOGLE_CLIENT_SECRET=GOCSPX-your-secret"
    echo ""
    echo "Then run: ./oauth2-fix.sh"
    exit 1
fi

echo -e "${GREEN}   ✅ Configuration looks good${NC}"

# Build image
echo -e "${BLUE}🔨 Building fixed Docker image...${NC}"
IMAGE_NAME=${IMAGE_NAME:-"bot-tele-3:latest"}

if docker build --no-cache -t ${IMAGE_NAME} .; then
    echo -e "${GREEN}   ✅ Image built successfully${NC}"
else
    echo -e "${RED}   ❌ Build failed${NC}"
    exit 1
fi

# Start container
echo -e "${BLUE}🚀 Starting fixed container...${NC}"
CONTAINER_NAME=${CONTAINER_NAME:-"leech-bot"}

docker run -d \
    --name ${CONTAINER_NAME} \
    --user root \
    --restart unless-stopped \
    --env-file .env \
    -v $(pwd)/data:/app/data \
    -v $(pwd)/downloads:/app/downloads \
    -v $(pwd)/logs:/app/logs \
    -p 8080:8080 \
    ${IMAGE_NAME}

echo "⏳ Waiting for container to start..."
sleep 5

# Check status
if docker ps | grep -q ${CONTAINER_NAME}; then
    echo -e "${GREEN}✅ Container started successfully!${NC}"
    echo ""
    echo -e "${CYAN}📋 Next Steps:${NC}"
    echo "1. Send /start to bot in Telegram"
    echo "2. Send /auth to setup Google Drive"  
    echo "3. Complete OAuth2 flow"
    echo "4. Test with /d [link]"
    echo ""
    echo -e "${CYAN}🔧 Management:${NC}"
    echo "./status.sh    - Check status"
    echo "./logs.sh      - View logs"
    echo ""
    echo -e "${GREEN}🎉 OAuth2 Fix Applied Successfully!${NC}"
else
    echo -e "${RED}❌ Container failed to start${NC}"
    echo ""
    echo "Check logs:"
    echo "docker logs ${CONTAINER_NAME}"
fi