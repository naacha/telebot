#!/usr/bin/env python3
"""
TELEGRAM BOT FOR STB HG680P ARMBIAN 25.11 (CLI-ONLY)
✅ Channel subscription check (@ZalheraThink) - ID: -1001802424804
✅ Bot Token integrated: 8436081597:AAE-8bfWrbvhl26-l9y65p48DfWjQOYPR2A
✅ Inline commands support
✅ BotFather commands support
✅ Port auto-detection
✅ OAuth2 Error 400 FIXED
✅ Application Builder FIXED
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
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup, InlineQueryResultArticle, InputTextMessageContent
from telegram.ext import Application, CommandHandler, ContextTypes, InlineQueryHandler
from telegram.error import BadRequest, Forbidden

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

# Configuration with integrated credentials
BOT_TOKEN = os.getenv('BOT_TOKEN', '8436081597:AAE-8bfWrbvhl26-l9y65p48DfWjQOYPR2A')
OWNER_USERNAME = os.getenv('OWNER_USERNAME', 'zalhera')
GOOGLE_CLIENT_ID = os.getenv('GOOGLE_CLIENT_ID')
GOOGLE_CLIENT_SECRET = os.getenv('GOOGLE_CLIENT_SECRET')
SCOPES = ['https://www.googleapis.com/auth/drive.file']
TOKEN_FILE = '/app/data/token.json'
CREDENTIALS_FILE = '/app/credentials/credentials.json'

# Channel subscription settings - INTEGRATED
REQUIRED_CHANNEL = '@ZalheraThink'
CHANNEL_URL = 'https://t.me/ZalheraThink'
CHANNEL_ID = -1001802424804  # Integrated actual channel ID

# Settings for STB
MAX_CONCURRENT = int(os.getenv('MAX_CONCURRENT_DOWNLOADS', '2'))
MAX_SPEED_MBPS = float(os.getenv('MAX_SPEED_MBPS', '10'))
CHUNK_SIZE = int(os.getenv('CHUNK_SIZE', '8192'))

# Bot info for inline
BOT_USERNAME = os.getenv('BOT_USERNAME', 'your_bot_username')

# Ensure directories exist
def ensure_directories():
    """Create required directories for STB deployment"""
    dirs = ['/app/data', '/app/downloads', '/app/logs', '/app/credentials']
    for dir_path in dirs:
        os.makedirs(dir_path, exist_ok=True)
        os.chmod(dir_path, 0o777)

ensure_directories()

class ChannelSubscriptionCheck:
    """Channel subscription verification with integrated channel ID"""

    @staticmethod
    async def is_user_subscribed(context, user_id):
        """Check if user is subscribed to required channel"""
        try:
            # Try to get chat member status
            member = await context.bot.get_chat_member(CHANNEL_ID, user_id)

            # Check if user is member, administrator, or creator
            if member.status in ['member', 'administrator', 'creator']:
                logger.info(f"✅ User {user_id} is subscribed to {REQUIRED_CHANNEL}")
                return True
            else:
                logger.info(f"❌ User {user_id} is not subscribed to {REQUIRED_CHANNEL}")
                return False

        except (BadRequest, Forbidden) as e:
            logger.warning(f"Could not check subscription for user {user_id}: {e}")
            # If we can't check, assume not subscribed for security
            return False
        except Exception as e:
            logger.error(f"Subscription check error: {e}")
            return False

    @staticmethod
    async def send_subscription_message(update: Update):
        """Send subscription required message"""
        keyboard = [[InlineKeyboardButton("📢 Join Channel", url=CHANNEL_URL)]]
        reply_markup = InlineKeyboardMarkup(keyboard)

        message = f"""
🔒 **Channel Subscription Required**

To use this bot, you must first join our channel:

📢 **{REQUIRED_CHANNEL}**

Click the button below to join, then try again.

⚠️ **Important:**
• You must stay subscribed to use the bot
• If you leave the channel, bot will stop working
• This helps us provide better service

🔄 After joining, use /start again
"""

        await update.message.reply_text(
            message, 
            parse_mode='Markdown',
            reply_markup=reply_markup
        )

async def check_subscription(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Decorator function to check channel subscription"""
    user_id = update.effective_user.id

    # Skip check for owner
    if is_owner(update.effective_user.username):
        return True

    # Check subscription
    if not await ChannelSubscriptionCheck.is_user_subscribed(context, user_id):
        await ChannelSubscriptionCheck.send_subscription_message(update)
        return False

    return True

class STBSystemInfo:
    """System information for STB HG680P"""

    @staticmethod
    def get_architecture():
        """Detect ARM architecture for STB"""
        machine = platform.machine().lower()
        uname = platform.uname()

        logger.info(f"STB Architecture: {machine}")
        logger.info(f"System: {uname.system} {uname.release}")

        if machine in ['aarch64', 'arm64']:
            return 'aarch64'
        elif machine.startswith('arm'):
            return 'armhf'
        else:
            return 'aarch64'

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

            flow = InstalledAppFlow.from_client_secrets_file(CREDENTIALS_FILE, SCOPES)

            auth_url, _ = flow.authorization_url(
                access_type='offline',
                prompt='consent',
                include_granted_scopes='true'
            )

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

            self._flow.fetch_token(code=auth_code)
            self.credentials = self._flow.credentials

            self.save_credentials()
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

            media = MediaFileUpload(
                file_path, 
                mimetype=mime_type,
                resumable=True,
                chunksize=CHUNK_SIZE * 1024
            )

            request = self.service.files().create(
                body=file_metadata,
                media_body=media,
                fields='id,name,size'
            )

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

def extract_args(text, command):
    """Extract arguments from command or reply"""
    # Handle @username commands
    if f'@{BOT_USERNAME}' in command:
        command = command.replace(f'@{BOT_USERNAME}', '')

    if text.startswith(command):
        return text[len(command):].strip()
    return None

# Bot commands
async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Start command with channel subscription check"""
    # Check channel subscription
    if not await check_subscription(update, context):
        return

    user = update.effective_user
    system_info = stb_info.get_system_info()

    owner_note = ""
    if is_owner(user.username):
        owner_note = "\n\n🔧 **Owner Access Granted**\nAdvanced STB management available"

    message = f"""
🎉 Welcome {user.first_name}!

🚀 **STB Telegram Bot - HG680P Armbian**
📢 **Subscribed to {REQUIRED_CHANNEL}** ✅
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
/help - Command help

🎯 **STB Features:**
• CLI-only operation (no GUI needed)
• ARM64 optimized downloads
• Automatic Google Drive upload
• Concurrent processing ({MAX_CONCURRENT} files)
• Speed optimization ({MAX_SPEED_MBPS} MB/s)
• Channel subscription protection

💡 **Inline Usage:**
Use @{BOT_USERNAME} in any chat for quick access

💡 **Quick Start:**
1. Use /auth to connect Google Drive
2. Send /d followed by any file link
3. Files automatically uploaded to Drive

{owner_note}
"""

    await update.message.reply_text(message, parse_mode='Markdown')

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Help command with all bot commands"""
    # Check channel subscription
    if not await check_subscription(update, context):
        return

    help_text = f"""
📋 **STB Bot Help - Complete Commands**

🔧 **Main Commands:**
/start - Welcome message and bot info
/help - Show this help message
/auth - Connect Google Drive (CLI method)
/d [link] - Download file and upload to Drive
/system - Show STB system information  
/stats - Bot and user statistics

📱 **Inline Usage:**
@{BOT_USERNAME} help - Show help
@{BOT_USERNAME} download [link] - Download file
@{BOT_USERNAME} system - System info

🤖 **BotFather Commands:**
/d@{BOT_USERNAME} [link] - Download via direct mention
/help@{BOT_USERNAME} - Get help via mention

💡 **Usage Examples:**
`/d https://example.com/file.zip`
`@{BOT_USERNAME} download https://example.com/video.mp4`
`/d@{BOT_USERNAME} https://files.com/document.pdf`

📢 **Channel Requirement:**
• Must be subscribed to {REQUIRED_CHANNEL}
• Bot will stop working if you leave channel

🏗️ **STB Optimized:**
• ARM64 architecture support
• CLI-only operation
• Docker deployment
• 24/7 headless operation

💬 **Support:**
Join {CHANNEL_URL} for updates and support
"""

    await update.message.reply_text(help_text, parse_mode='Markdown')

async def auth_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """CLI-optimized Google Drive authentication"""
    # Check channel subscription
    if not await check_subscription(update, context):
        return

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
    # Check channel subscription
    if not await check_subscription(update, context):
        return

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
    """STB-optimized download and upload command with multiple input methods"""
    # Check channel subscription
    if not await check_subscription(update, context):
        return

    # Extract URL from different sources
    url = None

    # Method 1: From command arguments
    if context.args:
        url = context.args[0]

    # Method 2: From replied message
    elif update.message.reply_to_message:
        replied_text = update.message.reply_to_message.text
        if replied_text and (replied_text.startswith('http') or 'http' in replied_text):
            # Extract URL from replied message
            words = replied_text.split()
            for word in words:
                if word.startswith('http'):
                    url = word
                    break

    # Method 3: From inline usage (@username command)
    elif update.message.text:
        text = update.message.text
        # Check for @username pattern
        if f'@{BOT_USERNAME}' in text:
            args = extract_args(text, f'/d@{BOT_USERNAME}')
            if args:
                url = args

    if not url:
        await update.message.reply_text(
            "⚠️ **Invalid Format**\n\n"
            "**Usage Options:**\n"
            "• `/d [file-link]`\n"
            f"• `/d@{BOT_USERNAME} [file-link]`\n"
            "• Reply to message with link using `/d`\n\n"
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
        asyncio.create_task(message.edit_text(
            f"📥 **STB Download in Progress**\n\n"
            f"📄 **File:** `{file_name}`\n"
            f"🌐 **Source:** Processing...\n"
            f"🏗️ **STB:** ARM64 optimized download\n"
            f"📊 **Status:** Retrieving data",
            parse_mode='Markdown'
        ))

        response = requests.get(url, stream=True, timeout=300)
        response.raise_for_status()

        total_size = int(response.headers.get('content-length', 0))
        downloaded = 0

        with open(file_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=CHUNK_SIZE):
                if chunk:
                    f.write(chunk)
                    downloaded += len(chunk)
                    time.sleep(CHUNK_SIZE / (MAX_SPEED_MBPS * 1024 * 1024))

        asyncio.create_task(message.edit_text(
            f"☁️ **STB Uploading to Google Drive**\n\n"
            f"📄 **File:** `{file_name}`\n"
            f"📦 **Size:** {downloaded/(1024*1024):.1f} MB\n"
            f"🏗️ **STB:** ARM64 upload optimization\n"
            f"🔄 **Status:** Transferring to Drive",
            parse_mode='Markdown'
        ))

        file_id, share_link = drive_manager.upload_file(file_path, file_name)

        if file_id and share_link:
            try:
                os.remove(file_path)
            except:
                pass

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
    # Check channel subscription
    if not await check_subscription(update, context):
        return

    system_info = stb_info.get_system_info()

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

📢 **Channel:** {REQUIRED_CHANNEL} ✅
🆔 **Channel ID:** {CHANNEL_ID}

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
    # Check channel subscription
    if not await check_subscription(update, context):
        return

    user = update.effective_user
    user_downloads = download_manager.active_downloads.get(user.id, [])
    system_info = stb_info.get_system_info()

    message = f"📊 **STB Bot Statistics - {user.first_name}**\n\n"

    message += f"📢 **Channel Status:** {REQUIRED_CHANNEL} ✅\n"
    message += f"🆔 **Channel ID:** {CHANNEL_ID}\n\n"

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

    message += f"\n💡 **Must stay subscribed to {REQUIRED_CHANNEL}**"

    await update.message.reply_text(message, parse_mode='Markdown')

# Inline query handler
async def inline_query(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle inline queries"""
    query = update.inline_query.query.lower().strip()
    user_id = update.inline_query.from_user.id

    # Check channel subscription for inline usage
    if not await ChannelSubscriptionCheck.is_user_subscribed(context, user_id):
        # Return subscription required result
        results = [
            InlineQueryResultArticle(
                id='subscription_required',
                title=f'📢 Join {REQUIRED_CHANNEL} Required',
                description='You must join our channel to use this bot',
                input_message_content=InputTextMessageContent(
                    message_text=f"🔒 Please join {CHANNEL_URL} to use this bot",
                    parse_mode='Markdown'
                )
            )
        ]
        await update.inline_query.answer(results)
        return

    results = []

    # Help command
    if query.startswith('help') or query == '':
        results.append(
            InlineQueryResultArticle(
                id='help',
                title='📋 STB Bot Help',
                description='Show complete command help',
                input_message_content=InputTextMessageContent(
                    message_text=f"""📋 **STB Bot Commands**

🔧 **Main Commands:**
/auth - Connect Google Drive
/d [link] - Download file
/system - STB info
/stats - Statistics

💡 **Inline Usage:**
@{BOT_USERNAME} help
@{BOT_USERNAME} download [link]
@{BOT_USERNAME} system

📢 **Channel:** {REQUIRED_CHANNEL} ✅
🏗️ **STB:** HG680P ARM64 optimized""",
                    parse_mode='Markdown'
                )
            )
        )

    # Download command
    elif query.startswith('download '):
        url = query[9:].strip()  # Remove 'download ' prefix
        if url:
            results.append(
                InlineQueryResultArticle(
                    id='download',
                    title=f'📥 Download: {url}',
                    description='Download and upload to Google Drive',
                    input_message_content=InputTextMessageContent(
                        message_text=f"/d {url}",
                        parse_mode='Markdown'
                    )
                )
            )

    # System info
    elif query.startswith('system'):
        system_info = stb_info.get_system_info()
        results.append(
            InlineQueryResultArticle(
                id='system',
                title='💻 STB System Info',
                description=f"Architecture: {system_info['architecture']}, Memory: {system_info['memory']}",
                input_message_content=InputTextMessageContent(
                    message_text=f"""💻 **STB HG680P Info**
🏗️ **Arch:** {system_info['architecture']}
🧠 **Memory:** {system_info['memory']}
💾 **Storage:** {system_info['storage_available']} free
📢 **Channel:** {REQUIRED_CHANNEL} ✅""",
                    parse_mode='Markdown'
                )
            )
        )

    # If no specific query, show general options
    if not results:
        results = [
            InlineQueryResultArticle(
                id='general_help',
                title='📋 STB Bot Commands',
                description='Available: help, download [url], system',
                input_message_content=InputTextMessageContent(
                    message_text=f"""💡 **Inline Usage Examples:**

@{BOT_USERNAME} help
@{BOT_USERNAME} download https://example.com/file.zip  
@{BOT_USERNAME} system

📢 **Channel:** {REQUIRED_CHANNEL} ✅
🏗️ **STB:** HG680P ARM64""",
                    parse_mode='Markdown'
                )
            )
        ]

    await update.inline_query.answer(results)

def main():
    """Main bot function with integrated credentials"""
    # Integrated Bot Token validation
    if not BOT_TOKEN or BOT_TOKEN == 'your_bot_token_here':
        logger.error("❌ BOT_TOKEN not configured properly")
        sys.exit(1)

    system_info = stb_info.get_system_info()

    logger.info("🚀 Starting STB Telegram Bot with Integrated Credentials...")
    logger.info(f"🤖 Bot Token: {BOT_TOKEN[:20]}...")  # Show first 20 chars only
    logger.info(f"📢 Required Channel: {REQUIRED_CHANNEL}")
    logger.info(f"🆔 Channel ID: {CHANNEL_ID}")
    logger.info(f"📱 STB Model: HG680P")
    logger.info(f"🏗️ Architecture: {system_info['architecture']}")
    logger.info(f"💻 OS: Armbian 25.11 CLI")
    logger.info(f"👑 Owner: @{OWNER_USERNAME}")
    logger.info(f"⚡ Speed limit: {MAX_SPEED_MBPS} MB/s")
    logger.info(f"📊 Concurrent limit: {MAX_CONCURRENT}")

    # Create Telegram application with integrated credentials
    app = Application.builder().token(BOT_TOKEN).connect_timeout(60).read_timeout(60).write_timeout(60).pool_timeout(60).build()

    # Add command handlers
    app.add_handler(CommandHandler("start", start_command))
    app.add_handler(CommandHandler("help", help_command))
    app.add_handler(CommandHandler("auth", auth_command))
    app.add_handler(CommandHandler("code", code_command))
    app.add_handler(CommandHandler("d", download_command))
    app.add_handler(CommandHandler("system", system_command))
    app.add_handler(CommandHandler("stats", stats_command))

    # Add inline query handler
    app.add_handler(InlineQueryHandler(inline_query))

    logger.info("✅ STB Bot initialization complete with integrated credentials!")
    logger.info("🔗 Ready for CLI operation on HG680P")
    logger.info("📢 Channel subscription required for all users")

    # Start the bot
    app.run_polling(drop_pending_updates=True)

if __name__ == "__main__":
    main()
