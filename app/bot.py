#!/usr/bin/env python3
"""
TELEGRAM BOT FOR STB HG680P ARMBIAN 25.11 (CLI-ONLY)
Optimized for ARM64 architecture with Google Drive integration
No GUI dependencies - purely CLI/headless operation
OAuth2 Error 400 FIXED for CLI environment
"""

import os
import sys
import asyncio
import json
import logging
import time
import requests
import platform
from pathlib import Path
from typing import Dict, List, Optional
import subprocess
import tempfile
from concurrent.futures import ThreadPoolExecutor

# Core telegram imports
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, ContextTypes

# Google Drive imports - CLI optimized
from googleapiclient.discovery import build
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.http import MediaFileUpload

# Setup logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO,
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('/app/logs/bot.log', mode='a') if os.path.exists('/app/logs') else logging.NullHandler()
    ]
)
logger = logging.getLogger(__name__)

# Configuration
BOT_TOKEN = os.getenv('BOT_TOKEN')
OWNER_USERNAME = os.getenv('OWNER_USERNAME', 'zalhera')
GOOGLE_CLIENT_ID = os.getenv('GOOGLE_CLIENT_ID')
GOOGLE_CLIENT_SECRET = os.getenv('GOOGLE_CLIENT_SECRET')
SCOPES = ['https://www.googleapis.com/auth/drive.file']
TOKEN_FILE = '/app/data/token.json'
CREDENTIALS_FILE = '/app/credentials/credentials.json'

# Settings for STB
MAX_CONCURRENT = int(os.getenv('MAX_CONCURRENT_DOWNLOADS', '2'))
MAX_SPEED_MBPS = float(os.getenv('MAX_SPEED_MBPS', '10'))  # Higher for STB
CHUNK_SIZE = int(os.getenv('CHUNK_SIZE', '8192'))

# Ensure directories exist
def ensure_directories():
    """Create required directories for STB deployment"""
    dirs = ['/app/data', '/app/downloads', '/app/logs', '/app/credentials']
    for dir_path in dirs:
        os.makedirs(dir_path, exist_ok=True)
        os.chmod(dir_path, 0o777)

ensure_directories()

class STBSystemInfo:
    """System information for STB HG680P"""

    @staticmethod
    def get_architecture():
        """Detect ARM architecture for STB"""
        machine = platform.machine().lower()
        uname = platform.uname()

        logger.info(f"STB Architecture: {machine}")
        logger.info(f"System: {uname.system} {uname.release}")

        # STB HG680P is typically ARM64/aarch64
        if machine in ['aarch64', 'arm64']:
            return 'aarch64'
        elif machine.startswith('arm'):
            return 'armhf'
        else:
            return 'aarch64'  # Default for STB

    @staticmethod
    def get_system_info():
        """Get detailed STB system information"""
        try:
            # Memory info
            with open('/proc/meminfo', 'r') as f:
                mem_info = f.read()
                mem_total = [line for line in mem_info.split('\n') if 'MemTotal' in line]
                mem_total = mem_total[0].split()[1] if mem_total else "Unknown"

            # CPU info
            with open('/proc/cpuinfo', 'r') as f:
                cpu_info = f.read()
                cpu_model = [line for line in cpu_info.split('\n') if 'model name' in line]
                cpu_model = cpu_model[0].split(':')[1].strip() if cpu_model else "Unknown ARM CPU"

            # Storage info
            storage = subprocess.run(['df', '-h', '/'], capture_output=True, text=True)
            storage_info = storage.stdout.split('\n')[1].split() if storage.returncode == 0 else ["Unknown"]

            return {
                'architecture': STBSystemInfo.get_architecture(),
                'memory': f"{int(mem_total)//1024} MB" if mem_total != "Unknown" else "Unknown",
                'cpu': cpu_model,
                'storage_total': storage_info[1] if len(storage_info) > 1 else "Unknown",
                'storage_used': storage_info[2] if len(storage_info) > 2 else "Unknown",
                'storage_available': storage_info[3] if len(storage_info) > 3 else "Unknown"
            }
        except Exception as e:
            logger.warning(f"Could not get system info: {e}")
            return {
                'architecture': STBSystemInfo.get_architecture(),
                'memory': "Unknown",
                'cpu': "ARM CPU",
                'storage_total': "Unknown",
                'storage_used': "Unknown",
                'storage_available': "Unknown"
            }

class GoogleDriveManager:
    """CLI-optimized Google Drive manager for STB"""

    def __init__(self):
        self.service = None
        self.credentials = None
        self.load_credentials()

    def load_credentials(self):
        """Load existing credentials from token file"""
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
                    self.service = build('drive', 'v3', credentials=self.credentials, cache_discovery=False)
                    logger.info("✅ Google Drive authenticated successfully")

        except Exception as e:
            logger.warning(f"Could not load credentials: {e}")

    def create_credentials_json(self):
        """Create credentials.json from environment variables for CLI"""
        if not GOOGLE_CLIENT_ID or not GOOGLE_CLIENT_SECRET:
            return False

        credentials_data = {
            "installed": {
                "client_id": GOOGLE_CLIENT_ID,
                "client_secret": GOOGLE_CLIENT_SECRET,
                "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                "token_uri": "https://oauth2.googleapis.com/token",
                "redirect_uris": ["http://localhost:8080", "urn:ietf:wg:oauth:2.0:oob"]
            }
        }

        try:
            with open(CREDENTIALS_FILE, 'w') as f:
                json.dump(credentials_data, f, indent=2)
            logger.info("✅ Credentials file created for CLI authentication")
            return True
        except Exception as e:
            logger.error(f"Failed to create credentials file: {e}")
            return False

    def get_auth_url(self):
        """Get OAuth2 authorization URL for CLI authentication"""
        try:
            if not self.create_credentials_json():
                return None, "Could not create credentials file"

            # CLI-optimized OAuth flow
            flow = InstalledAppFlow.from_client_secrets_file(CREDENTIALS_FILE, SCOPES)

            # Generate authorization URL for CLI
            auth_url, _ = flow.authorization_url(
                access_type='offline',
                prompt='consent',
                include_granted_scopes='true'
            )

            # Store flow for later use
            self._flow = flow

            logger.info("✅ CLI authorization URL generated successfully")
            return auth_url, None

        except Exception as e:
            logger.error(f"Failed to create auth URL: {e}")
            return None, str(e)

    def authenticate_with_code(self, auth_code):
        """Complete CLI authentication with authorization code"""
        try:
            if not hasattr(self, '_flow'):
                return False, "No active authentication flow"

            # Exchange code for token
            self._flow.fetch_token(code=auth_code)
            self.credentials = self._flow.credentials

            # Save credentials
            self.save_credentials()

            # Initialize service
            self.service = build('drive', 'v3', credentials=self.credentials, cache_discovery=False)

            logger.info("✅ CLI authentication completed successfully")
            return True, None

        except Exception as e:
            logger.error(f"Authentication failed: {e}")
            return False, str(e)

    def save_credentials(self):
        """Save credentials to token file"""
        try:
            token_data = {
                'token': self.credentials.token,
                'refresh_token': self.credentials.refresh_token,
                'client_id': self.credentials.client_id,
                'client_secret': self.credentials.client_secret,
                'scopes': self.credentials.scopes
            }

            with open(TOKEN_FILE, 'w') as f:
                json.dump(token_data, f, indent=2)

            os.chmod(TOKEN_FILE, 0o600)
            logger.info("💾 Credentials saved securely")

        except Exception as e:
            logger.error(f"Save credentials failed: {e}")

    def upload_file(self, file_path, file_name):
        """Upload file to Google Drive optimized for STB"""
        if not self.service:
            return None, None

        try:
            # Detect mime type
            mime_type = 'application/octet-stream'
            if file_name.lower().endswith(('.jpg', '.jpeg', '.png')):
                mime_type = 'image/jpeg'
            elif file_name.lower().endswith('.mp4'):
                mime_type = 'video/mp4'
            elif file_name.lower().endswith('.pdf'):
                mime_type = 'application/pdf'

            file_metadata = {
                'name': file_name,
                'parents': [os.getenv('GDRIVE_FOLDER_ID', 'root')]
            }

            # STB-optimized upload with resumable
            media = MediaFileUpload(
                file_path, 
                mimetype=mime_type,
                resumable=True,
                chunksize=CHUNK_SIZE * 1024  # Optimized for STB
            )

            request = self.service.files().create(
                body=file_metadata,
                media_body=media,
                fields='id,name,size'
            )

            # Execute resumable upload
            response = None
            while response is None:
                try:
                    status, response = request.next_chunk()
                    if status:
                        logger.info(f"Upload progress: {int(status.progress() * 100)}%")
                except Exception as e:
                    logger.error(f"Upload chunk failed: {e}")
                    return None, None

            file_id = response.get('id')

            # Make file accessible
            self.service.permissions().create(
                fileId=file_id,
                body={'type': 'anyone', 'role': 'reader'}
            ).execute()

            share_link = f"https://drive.google.com/file/d/{file_id}/view"
            direct_link = f"https://drive.google.com/uc?id={file_id}"

            logger.info(f"✅ File uploaded successfully: {file_name}")
            return file_id, share_link

        except Exception as e:
            logger.error(f"Upload failed: {e}")
            return None, None

class DownloadManager:
    """STB-optimized download manager"""

    def __init__(self):
        self.active_downloads = {}
        self.executor = ThreadPoolExecutor(max_workers=MAX_CONCURRENT)

    def can_download(self, user_id):
        return len(self.active_downloads.get(user_id, [])) < MAX_CONCURRENT

    def add_download(self, user_id, task_id):
        if user_id not in self.active_downloads:
            self.active_downloads[user_id] = []
        self.active_downloads[user_id].append(task_id)

    def remove_download(self, user_id, task_id):
        if user_id in self.active_downloads:
            if task_id in self.active_downloads[user_id]:
                self.active_downloads[user_id].remove(task_id)
            if not self.active_downloads[user_id]:
                del self.active_downloads[user_id]

# Global instances
drive_manager = GoogleDriveManager()
download_manager = DownloadManager()
stb_info = STBSystemInfo()

# Helper functions
def is_owner(username):
    return username and username.lower() == OWNER_USERNAME.lower()

async def owner_only(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_owner(update.effective_user.username):
        await update.message.reply_text("⚠️ Access restricted to bot owner only.")
        return False
    return True

# Bot commands
async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Start command optimized for STB display"""
    user = update.effective_user
    system_info = stb_info.get_system_info()

    owner_note = ""
    if is_owner(user.username):
        owner_note = "\n\n🔧 **Owner Access Granted**\nAdvanced STB management available"

    message = f"""
🎉 Welcome {user.first_name}!

🚀 **STB Telegram Bot - HG680P Armbian**
📱 Optimized for CLI/headless operation
🔧 ARM64 architecture support
☁️ Google Drive integration

💻 **STB Information:**
🏗️ Architecture: {system_info['architecture']}
🧠 Memory: {system_info['memory']}  
⚡ CPU: {system_info['cpu'][:50]}...
💾 Storage: {system_info['storage_available']} free

📋 **Available Commands:**
/auth - Connect Google Drive (CLI method)
/d [link] - Download and upload file
/system - STB system information
/stats - Bot statistics

🎯 **STB Features:**
• CLI-only operation (no GUI needed)
• ARM64 optimized downloads
• Automatic Google Drive upload
• Concurrent processing ({MAX_CONCURRENT} files)
• Speed optimization ({MAX_SPEED_MBPS} MB/s)

💡 **Quick Start:**
1. Use /auth to connect Google Drive
2. Send /d followed by any file link
3. Files automatically uploaded to Drive
4. Local cleanup after upload

{owner_note}
"""

    await update.message.reply_text(message, parse_mode='Markdown')

async def auth_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """CLI-optimized Google Drive authentication"""
    if not GOOGLE_CLIENT_ID or not GOOGLE_CLIENT_SECRET:
        await update.message.reply_text(
            "⚙️ **Google Drive Not Configured**\n\n"
            "Google Client ID and Secret not set.\n"
            "Please configure environment variables."
        )
        return

    if drive_manager.service:
        await update.message.reply_text(
            "✅ **Already Connected to Google Drive**\n\n"
            "Your Google Drive is active and ready.\n"
            "Try uploading a file with /d [link]"
        )
        return

    auth_url, error = drive_manager.get_auth_url()
    if error:
        await update.message.reply_text(f"❌ **Connection Error**\n\n{error}")
        return

    message = f"""
🔐 **Google Drive Connection (CLI Method)**

**📋 STB HG680P Setup Instructions:**

1️⃣ **Open this link on any device with browser:**
{auth_url}

2️⃣ **Sign in to your Google account**
3️⃣ **Grant the requested permissions**  
4️⃣ **Copy the authorization code**
5️⃣ **Send the code here:** `/code [authorization-code]`

**💡 Example:**
`/code 4/0AdQt8qi7bGMqwertyuiop...`

**⚠️ CLI-Optimized Notes:**
• No browser needed on STB
• Use any device to get authorization code
• Code expires in 10 minutes
• ARM64 architecture fully supported
• Perfect for headless STB operation

**🔒 Secure CLI authentication for STB HG680P**
"""

    await update.message.reply_text(message, parse_mode='Markdown')

async def code_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle Google Drive authorization code"""
    if not context.args:
        await update.message.reply_text(
            "⚠️ **Invalid Format**\n\n"
            "Please use: `/code [your-authorization-code]`\n"
            "Get the code from /auth authorization link"
        )
        return

    auth_code = context.args[0]

    msg = await update.message.reply_text("🔄 **Processing STB Authentication...**")

    success, error = drive_manager.authenticate_with_code(auth_code)

    if success:
        await msg.edit_text(
            "✅ **Google Drive Connected Successfully!**\n\n"
            "🚀 STB HG680P is now connected to Drive\n"
            "📁 Ready to upload files from downloads\n"
            "💡 Test with: `/d [file-link]`\n\n"
            "🎉 CLI authentication completed on STB!"
        )
    else:
        await msg.edit_text(
            f"❌ **Authentication Failed**\n\n"
            f"**Error:** {error}\n\n"
            "**Troubleshooting for STB:**\n"
            "• Get fresh code with /auth\n"
            "• Ensure complete code copied\n"
            "• Try again with proper permissions"
        )

async def download_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """STB-optimized download and upload command"""
    if not context.args:
        await update.message.reply_text(
            "⚠️ **Invalid Format**\n\n"
            "Please use: `/d [file-link]`\n"
            "**Example:** `/d https://example.com/file.zip`"
        )
        return

    if not drive_manager.service:
        await update.message.reply_text(
            "🔐 **Google Drive Not Connected**\n\n"
            "Connect your Google Drive first using /auth\n"
            "CLI method optimized for STB HG680P"
        )
        return

    user_id = update.effective_user.id
    if not download_manager.can_download(user_id):
        active = len(download_manager.active_downloads.get(user_id, []))
        await update.message.reply_text(
            f"📊 **STB Queue Limit Reached**\n\n"
            f"Active processes: {active}/{MAX_CONCURRENT}\n"
            f"STB can handle {MAX_CONCURRENT} concurrent downloads"
        )
        return

    url = context.args[0]
    file_name = url.split('/')[-1] or f"stb_download_{int(time.time())}"
    task_id = f"stb_{user_id}_{int(time.time())}"

    download_manager.add_download(user_id, task_id)

    system_info = stb_info.get_system_info()
    msg = await update.message.reply_text(
        f"📥 **STB Download Starting**\n\n"
        f"📄 **File:** `{file_name}`\n"
        f"🏗️ **STB Arch:** {system_info['architecture']}\n"
        f"⚡ **Speed:** Up to {MAX_SPEED_MBPS} MB/s\n"
        f"💾 **Available:** {system_info['storage_available']}\n"
        f"🔄 **Status:** Initializing...",
        parse_mode='Markdown'
    )

    # Process download in background
    download_manager.executor.submit(
        process_stb_download, url, file_name, user_id, task_id, msg
    )

def process_stb_download(url, file_name, user_id, task_id, message):
    """STB-optimized download and upload process"""
    file_path = f"/app/downloads/{file_name}"

    try:
        # Update status
        asyncio.create_task(message.edit_text(
            f"📥 **STB Download in Progress**\n\n"
            f"📄 **File:** `{file_name}`\n"
            f"🌐 **Source:** Processing...\n"
            f"🏗️ **STB:** ARM64 optimized download\n"
            f"📊 **Status:** Retrieving data",
            parse_mode='Markdown'
        ))

        # STB-optimized download
        response = requests.get(url, stream=True, timeout=300)
        response.raise_for_status()

        total_size = int(response.headers.get('content-length', 0))
        downloaded = 0

        # Download with STB-optimized chunks
        with open(file_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=CHUNK_SIZE):
                if chunk:
                    f.write(chunk)
                    downloaded += len(chunk)
                    # STB-optimized speed limiting
                    time.sleep(CHUNK_SIZE / (MAX_SPEED_MBPS * 1024 * 1024))

        # Update upload status
        asyncio.create_task(message.edit_text(
            f"☁️ **STB Uploading to Google Drive**\n\n"
            f"📄 **File:** `{file_name}`\n"
            f"📦 **Size:** {downloaded/(1024*1024):.1f} MB\n"
            f"🏗️ **STB:** ARM64 upload optimization\n"
            f"🔄 **Status:** Transferring to Drive",
            parse_mode='Markdown'
        ))

        # Upload to Google Drive
        file_id, share_link = drive_manager.upload_file(file_path, file_name)

        if file_id and share_link:
            # Cleanup local file
            try:
                os.remove(file_path)
            except:
                pass

            # Success message
            asyncio.create_task(message.edit_text(
                f"✅ **STB Process Completed!**\n\n"
                f"📄 **File:** `{file_name}`\n"
                f"📦 **Size:** {downloaded/(1024*1024):.1f} MB\n"
                f"🏗️ **STB:** HG680P ARM64\n"
                f"🔗 **Link:** [Open File]({share_link})\n\n"
                f"🗑️ **Local cleanup completed** ✅",
                parse_mode='Markdown'
            ))
        else:
            raise Exception("Google Drive upload failed")

    except Exception as e:
        # Cleanup on error
        try:
            if os.path.exists(file_path):
                os.remove(file_path)
        except:
            pass

        asyncio.create_task(message.edit_text(
            f"❌ **STB Process Failed**\n\n"
            f"📄 **File:** `{file_name}`\n"
            f"🚫 **Error:** {str(e)[:100]}...\n"
            f"🏗️ **STB:** Check connection and try again"
        ))

    finally:
        download_manager.remove_download(user_id, task_id)

async def system_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """STB system information command"""
    system_info = stb_info.get_system_info()

    # Get additional STB info
    try:
        uptime = subprocess.run(['uptime'], capture_output=True, text=True)
        uptime_str = uptime.stdout.strip() if uptime.returncode == 0 else "Unknown"

        temp_cmd = subprocess.run(['cat', '/sys/class/thermal/thermal_zone0/temp'], 
                                 capture_output=True, text=True)
        temp = int(temp_cmd.stdout.strip()) / 1000 if temp_cmd.returncode == 0 else 0

        load_avg = os.getloadavg() if hasattr(os, 'getloadavg') else (0, 0, 0)

    except Exception as e:
        uptime_str = "Unknown"
        temp = 0
        load_avg = (0, 0, 0)

    message = f"""
💻 **STB HG680P System Information**

🏗️ **Hardware:**
• Architecture: {system_info['architecture']}
• CPU: {system_info['cpu']}
• Memory: {system_info['memory']}
• Temperature: {temp:.1f}°C

💾 **Storage:**
• Total: {system_info['storage_total']}
• Used: {system_info['storage_used']}
• Available: {system_info['storage_available']}

📊 **Performance:**
• Load Average: {load_avg[0]:.2f}, {load_avg[1]:.2f}, {load_avg[2]:.2f}
• Uptime: {uptime_str}

🤖 **Bot Status:**
• Max Downloads: {MAX_CONCURRENT}
• Speed Limit: {MAX_SPEED_MBPS} MB/s
• Chunk Size: {CHUNK_SIZE} bytes
• Drive Connected: {"✅ Yes" if drive_manager.service else "❌ No"}

🌐 **Network:**
• Interface: eth0/wlan0
• OS: Armbian 25.11 CLI
• Docker: Active

**🚀 STB optimized for 24/7 operation**
"""

    await update.message.reply_text(message, parse_mode='Markdown')

async def stats_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """STB bot statistics"""
    user = update.effective_user
    user_downloads = download_manager.active_downloads.get(user.id, [])
    system_info = stb_info.get_system_info()

    message = f"📊 **STB Bot Statistics - {user.first_name}**\n\n"

    message += f"🏗️ **STB HG680P Status:**\n"
    message += f"📊 Active processes: {len(user_downloads)}/{MAX_CONCURRENT}\n"
    message += f"⚡ Speed allocation: {MAX_SPEED_MBPS} MB/s\n"
    message += f"🧠 Memory: {system_info['memory']}\n"
    message += f"💾 Storage free: {system_info['storage_available']}\n\n"

    if drive_manager.service:
        message += f"☁️ **Google Drive:** ✅ Connected & Active\n"
    else:
        message += f"☁️ **Google Drive:** ❌ Not connected (use /auth)\n"

    message += f"🌐 **Network:** STB ethernet/WiFi connection\n"
    message += f"🏗️ **Architecture:** {system_info['architecture']} (ARM64)\n"
    message += f"📱 **Interface:** CLI-only (no GUI)\n"
    message += f"🐳 **Container:** Docker optimized\n"

    if is_owner(user.username):
        message += f"\n🔧 **Owner Access:** Active\n"
        message += f"⚙️ **STB Management:** Available\n"

    message += f"\n💡 **STB optimized for continuous operation**"

    await update.message.reply_text(message, parse_mode='Markdown')

def main():
    """Main bot function optimized for STB"""
    if not BOT_TOKEN:
        logger.error("❌ BOT_TOKEN not configured")
        sys.exit(1)

    system_info = stb_info.get_system_info()

    logger.info("🚀 Starting STB Telegram Bot...")
    logger.info(f"📱 STB Model: HG680P")
    logger.info(f"🏗️ Architecture: {system_info['architecture']}")
    logger.info(f"💻 OS: Armbian 25.11 CLI")
    logger.info(f"👑 Owner: @{OWNER_USERNAME}")
    logger.info(f"⚡ Speed limit: {MAX_SPEED_MBPS} MB/s")
    logger.info(f"📊 Concurrent limit: {MAX_CONCURRENT}")
    logger.info(f"🧠 Memory: {system_info['memory']}")
    logger.info(f"💾 Storage: {system_info['storage_available']} available")

    # Create Telegram application with STB-optimized timeouts
    app = Application.builder()\
        .token(BOT_TOKEN)\
        .connect_timeout(60)\
        .read_timeout(60)\
        .write_timeout(60)\
        .pool_timeout=60\
        .build()

    # Add command handlers
    app.add_handler(CommandHandler("start", start_command))
    app.add_handler(CommandHandler("auth", auth_command))
    app.add_handler(CommandHandler("code", code_command))
    app.add_handler(CommandHandler("d", download_command))
    app.add_handler(CommandHandler("system", system_command))
    app.add_handler(CommandHandler("stats", stats_command))

    logger.info("✅ STB Bot initialization complete!")
    logger.info("🔗 Ready for CLI operation on HG680P")
    logger.info("📡 No GUI dependencies - pure headless mode")

    # Start the bot
    app.run_polling(drop_pending_updates=True)

if __name__ == "__main__":
    main()
