#!/usr/bin/env python3
"""
Telegram Bot - Complete Enhanced Version with ALL FIXES
Features: OAuth2 FIXED, Speed test FIXED, Inline support, Auto port detection, Owner commands
Author: Built for @zalhera
FIXES: OAuth2 response_type conflict, speedtest architecture detection, platform requirement, Docker health check
"""

import os
import sys
import asyncio
import json
import logging
import time
import requests
import shutil
import platform  # Built-in Python module (not from PyPI)
from pathlib import Path
from typing import Dict, List, Optional
import sqlite3
import threading
from concurrent.futures import ThreadPoolExecutor
import subprocess
import re

# Telegram imports
try:
    from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup, InlineQueryResultArticle, InputTextMessageContent
    from telegram.ext import Application, CommandHandler, ContextTypes, InlineQueryHandler
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
    print("✅ Cloud storage libraries loaded")
except ImportError as e:
    print(f"❌ Cloud storage import error: {e}")
    sys.exit(1)

# Setup logging
logging.basicConfig(
    format='%(asctime)s - %(levelname)s - %(message)s',
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
GOOGLE_REDIRECT_URI = os.getenv('GOOGLE_REDIRECT_URI', 'http://localhost:8080')
SCOPES = ['https://www.googleapis.com/auth/drive.file']
TOKEN_FILE = '/app/data/token.json'
ENV_FILE = '/app/.env'

# Settings
MAX_CONCURRENT = int(os.getenv('MAX_CONCURRENT_DOWNLOADS', '2'))
MAX_SPEED_MBPS = float(os.getenv('MAX_SPEED_MBPS', '5'))

# Ensure directories exist at runtime
def ensure_directories():
    """Ensure all required directories exist"""
    dirs = ['/app/data', '/app/downloads', '/app/logs']
    for dir_path in dirs:
        os.makedirs(dir_path, exist_ok=True)
        os.chmod(dir_path, 0o777)

# Call at startup
ensure_directories()

class SpeedTest:
    """FIXED Speedtest functionality with architecture detection"""

    @staticmethod
    def detect_architecture():
        """Detect system architecture for correct speedtest binary"""
        machine = platform.machine().lower()
        logger.info(f"Detected architecture: {machine}")

        # Architecture mapping
        arch_map = {
            'x86_64': 'x86_64',
            'amd64': 'x86_64', 
            'aarch64': 'aarch64',
            'arm64': 'aarch64',
            'armv7l': 'armhf',
            'armv6l': 'armel'
        }

        return arch_map.get(machine, 'x86_64')  # Default to x86_64

    @staticmethod
    def get_speedtest_url():
        """Get correct speedtest download URL based on architecture"""
        arch = SpeedTest.detect_architecture()

        urls = {
            'x86_64': 'https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-x86_64.tgz',
            'aarch64': 'https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-aarch64.tgz',
            'armhf': 'https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-armhf.tgz',
            'armel': 'https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-armel.tgz'
        }

        return urls.get(arch, urls['x86_64'])

    @staticmethod
    def install_speedtest():
        """FIXED: Install speedtest-cli with correct architecture detection"""
        try:
            # Check if already installed and working
            result = subprocess.run(['speedtest', '--version'], capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                logger.info("✅ Speedtest already installed and working")
                return True
        except FileNotFoundError:
            pass
        except Exception as e:
            logger.warning(f"Speedtest check failed: {e}")

        try:
            # Get correct URL for architecture
            download_url = SpeedTest.get_speedtest_url()
            arch = SpeedTest.detect_architecture()

            logger.info(f"Installing Ookla speedtest-cli for {arch}...")
            logger.info(f"Download URL: {download_url}")

            # Download and install with architecture detection
            commands = [
                ['wget', '-O', '/tmp/speedtest.tgz', download_url],
                ['tar', '-xzf', '/tmp/speedtest.tgz', '-C', '/tmp/'],
                ['chmod', '+x', '/tmp/speedtest'],
                ['mv', '/tmp/speedtest', '/usr/local/bin/speedtest'],
                ['rm', '-f', '/tmp/speedtest.tgz']
            ]

            for cmd in commands:
                logger.info(f"Running: {' '.join(cmd)}")
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
                if result.returncode != 0:
                    logger.error(f"Command failed: {' '.join(cmd)}")
                    logger.error(f"Error: {result.stderr}")
                    return False

            # Verify installation with architecture check
            result = subprocess.run(['file', '/usr/local/bin/speedtest'], capture_output=True, text=True, timeout=10)
            logger.info(f"Speedtest binary info: {result.stdout}")

            # Test execution
            result = subprocess.run(['speedtest', '--version'], capture_output=True, text=True, timeout=15)
            if result.returncode == 0:
                logger.info(f"✅ Speedtest-cli installed successfully: {result.stdout.strip()}")
                return True
            else:
                logger.error(f"Speedtest version check failed: {result.stderr}")
                return False

        except Exception as e:
            logger.error(f"Failed to install speedtest: {e}")
            return False

    @staticmethod
    def run_speedtest():
        """FIXED: Run speedtest with better error handling"""
        try:
            # Accept license automatically
            logger.info("Accepting speedtest license...")
            subprocess.run(['speedtest', '--accept-license'], capture_output=True, timeout=15)

            # Run speedtest with JSON output
            logger.info("Running speedtest...")
            result = subprocess.run(['speedtest', '--format=json'], capture_output=True, text=True, timeout=90)

            if result.returncode == 0:
                try:
                    data = json.loads(result.stdout)
                    return {
                        'success': True,
                        'download': data.get('download', {}).get('bandwidth', 0) * 8 / 1000000,  # Convert to Mbps
                        'upload': data.get('upload', {}).get('bandwidth', 0) * 8 / 1000000,  # Convert to Mbps
                        'ping': data.get('ping', {}).get('latency', 0),
                        'server': data.get('server', {}).get('name', 'Unknown'),
                        'isp': data.get('isp', 'Unknown'),
                        'location': data.get('server', {}).get('location', 'Unknown')
                    }
                except json.JSONDecodeError as e:
                    logger.error(f"JSON decode error: {e}")
                    return {'success': False, 'error': 'Invalid speedtest output format'}
            else:
                logger.error(f"Speedtest failed with code {result.returncode}")
                logger.error(f"Stderr: {result.stderr}")
                return {'success': False, 'error': result.stderr or 'Speedtest execution failed'}

        except subprocess.TimeoutExpired:
            return {'success': False, 'error': 'Speedtest timed out (>90 seconds)'}
        except Exception as e:
            logger.error(f"Speedtest exception: {e}")
            return {'success': False, 'error': str(e)}

class CloudStorageManager:
    """FIXED Cloud storage manager - OAuth2 response_type conflict resolved"""

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
                    logger.info("✅ Cloud storage authenticated")

        except Exception as e:
            logger.warning(f"⚠️ Could not load credentials: {e}")

    def get_auth_url(self):
        """FIXED: Get OAuth2 authorization URL - response_type conflict resolved"""
        try:
            if not GOOGLE_CLIENT_ID or not GOOGLE_CLIENT_SECRET:
                return None, "Cloud storage credentials not configured"

            # Get current port from environment
            current_port = os.getenv('OAUTH_PORT', '8080')
            redirect_uri = f"http://localhost:{current_port}"

            # FIXED: Proper web application config with explicit parameters
            client_config = {
                "web": {
                    "client_id": GOOGLE_CLIENT_ID,
                    "client_secret": GOOGLE_CLIENT_SECRET,
                    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                    "token_uri": "https://oauth2.googleapis.com/token",
                    "redirect_uris": [redirect_uri]
                }
            }

            flow = Flow.from_client_config(client_config, scopes=SCOPES)
            flow.redirect_uri = redirect_uri

            # FIXED: Remove conflicting response_type parameter
            # The prepare_grant_uri method already sets response_type internally
            auth_url, _ = flow.authorization_url(
                access_type='offline',
                prompt='consent',
                include_granted_scopes='true'
                # REMOVED: response_type='code'  # This was causing the conflict
            )

            logger.info(f"✅ Auth URL generated successfully for port {current_port}")
            return auth_url, None

        except Exception as e:
            logger.error(f"❌ Failed to create auth URL: {e}")
            return None, str(e)

    def authenticate_with_code(self, auth_code):
        """Complete authentication with authorization code"""
        try:
            current_port = os.getenv('OAUTH_PORT', '8080')
            redirect_uri = f"http://localhost:{current_port}"

            client_config = {
                "web": {
                    "client_id": GOOGLE_CLIENT_ID,
                    "client_secret": GOOGLE_CLIENT_SECRET,
                    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                    "token_uri": "https://oauth2.googleapis.com/token",
                    "redirect_uris": [redirect_uri]
                }
            }

            flow = Flow.from_client_config(client_config, scopes=SCOPES)
            flow.redirect_uri = redirect_uri

            # Exchange code for token
            flow.fetch_token(code=auth_code)
            self.credentials = flow.credentials

            # Save and initialize service
            self.save_credentials()
            self.service = build('drive', 'v3', credentials=self.credentials)

            logger.info("✅ OAuth2 authentication completed successfully")
            return True, None

        except Exception as e:
            logger.error(f"❌ Authentication failed: {e}")
            return False, str(e)

    def save_credentials(self):
        """Save credentials securely"""
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
            logger.error(f"❌ Save credentials failed: {e}")

    def upload_file(self, file_path, file_name):
        """Upload file to Google Drive"""
        if not self.service:
            return None, None

        try:
            file_metadata = {'name': file_name}
            media = MediaFileUpload(file_path, resumable=True)

            file = self.service.files().create(
                body=file_metadata,
                media_body=media,
                fields='id'
            ).execute()

            file_id = file.get('id')

            # Make file accessible to anyone with link
            self.service.permissions().create(
                fileId=file_id,
                body={'type': 'anyone', 'role': 'reader'}
            ).execute()

            share_link = f"https://drive.google.com/file/d/{file_id}/view"
            logger.info(f"✅ File uploaded: {file_name}")
            return file_id, share_link

        except Exception as e:
            logger.error(f"❌ Upload failed: {e}")
            return None, None

class DownloadManager:
    """Professional download manager"""

    def __init__(self):
        self.active_downloads = {}
        self.executor = ThreadPoolExecutor(max_workers=5)

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
storage_manager = CloudStorageManager()
download_manager = DownloadManager()
speedtest = SpeedTest()

# Auto-install speedtest on startup
logger.info("🚀 Initializing speedtest installation...")
if not speedtest.install_speedtest():
    logger.warning("⚠️ Speedtest installation failed, but bot will continue")

# Helper functions
def is_owner(username):
    return username and username.lower() == OWNER_USERNAME.lower()

async def owner_only(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_owner(update.effective_user.username):
        await update.message.reply_text("⚠️ Access restricted to authorized administrators only.")
        return False
    return True

# Bot commands
async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Professional start command"""
    user = update.effective_user

    owner_note = ""
    if is_owner(user.username):
        owner_note = "\n\n🔧 **Administrator Access Granted**\nAdvanced configuration tools available"

    message = f"""
🎉 Welcome {user.first_name}!

🚀 **Advanced File Manager Bot**
📁 Secure cloud storage integration
⚡ High-speed downloads with smart queuing
🌐 Network speed testing with Ookla

📋 **Available Commands:**
/auth - Connect cloud storage account
/d [link] - Download and upload file
/speedtest - Test network speed
/stats - View your account statistics

🎯 **Key Features:**
• Smart speed optimization ({MAX_SPEED_MBPS} MB/s)
• Concurrent processing (up to {MAX_CONCURRENT} files)
• Automatic file cleanup and organization
• Secure cloud integration with enterprise-grade encryption
• Network diagnostics and speed testing

💡 **Quick Start:**
1. Use /auth to connect your cloud storage
2. Send /d followed by any file link to start
3. Use /speedtest to check your connection
4. Files are automatically uploaded and local copies cleaned

{owner_note}
"""

    await update.message.reply_text(message, parse_mode='Markdown')

async def auth_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """FIXED OAuth2 authentication command"""
    if not GOOGLE_CLIENT_ID or not GOOGLE_CLIENT_SECRET:
        await update.message.reply_text(
            "⚙️ **Service Configuration Required**\n\n"
            "Cloud storage integration is not yet configured.\n"
            "Please contact the administrator to complete setup."
        )
        return

    if storage_manager.service:
        await update.message.reply_text(
            "✅ **Already Connected**\n\n"
            "Your cloud storage is active and ready to use.\n"
            "Try downloading a file with /d [link]"
        )
        return

    auth_url, error = storage_manager.get_auth_url()
    if error:
        await update.message.reply_text(f"❌ **Connection Error**\n\n{error}")
        return

    current_port = os.getenv('OAUTH_PORT', '8080')
    message = f"""
🔐 **Cloud Storage Connection**

**📋 Setup Instructions:**

1️⃣ **Click the authorization link below:**
{auth_url}

2️⃣ **Sign in to your Google account**
3️⃣ **Grant the requested permissions**
4️⃣ **Copy the authorization code from the confirmation page**
5️⃣ **Send the code using:** `/code [your-authorization-code]`

**💡 Example:**
`/code 4/0AdQt8qi7bGMqwertyuiop...`

**⚠️ Important Notes:**
• Authorization code expires in 10 minutes
• Use the complete code (may be lengthy)
• OAuth callback port: {current_port}
• Ensure no extra spaces or characters

**🔒 This connection uses enterprise-grade security protocols**
"""

    await update.message.reply_text(message, parse_mode='Markdown')

async def code_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle authorization code"""
    if not context.args:
        await update.message.reply_text(
            "⚠️ **Invalid Format**\n\n"
            "Please use: `/code [your-authorization-code]`\n"
            "Get the code from the /auth authorization link"
        )
        return

    auth_code = context.args[0]

    msg = await update.message.reply_text("🔄 **Processing Connection...**")

    success, error = storage_manager.authenticate_with_code(auth_code)

    if success:
        await msg.edit_text(
            "✅ **Connection Established Successfully!**\n\n"
            "🚀 Cloud storage is now active\n"
            "📁 Ready to process file downloads\n"
            "💡 Test with: `/d [file-link]`\n\n"
            "🎉 You can now enjoy seamless file management!"
        )
    else:
        await msg.edit_text(
            f"❌ **Connection Failed**\n\n"
            f"**Error Details:** {error}\n\n"
            "**Troubleshooting:**\n"
            "• Request a fresh authorization link with /auth\n"
            "• Verify the complete code was copied\n"
            "• Ensure proper account permissions were granted"
        )

async def download_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Professional download command"""
    if not context.args:
        await update.message.reply_text(
            "⚠️ **Invalid Format**\n\n"
            "Please use: `/d [file-link]`\n"
            "**Example:** `/d https://example.com/document.pdf`"
        )
        return

    if not storage_manager.service:
        await update.message.reply_text(
            "🔐 **Cloud Storage Not Connected**\n\n"
            "Please connect your cloud storage first using /auth"
        )
        return

    user_id = update.effective_user.id
    if not download_manager.can_download(user_id):
        active = len(download_manager.active_downloads.get(user_id, []))
        await update.message.reply_text(
            f"📊 **Queue Limit Reached**\n\n"
            f"Active processes: {active}/{MAX_CONCURRENT}\n"
            f"Please wait for current downloads to complete"
        )
        return

    url = context.args[0]
    file_name = url.split('/')[-1] or f"file_{int(time.time())}"
    task_id = f"{user_id}_{int(time.time())}"

    download_manager.add_download(user_id, task_id)

    msg = await update.message.reply_text(
        f"📥 **Initiating Download**\n\n"
        f"📄 **File:** `{file_name}`\n"
        f"⚡ **Speed:** Up to {MAX_SPEED_MBPS} MB/s\n"
        f"🔄 **Status:** Processing...",
        parse_mode='Markdown'
    )

    download_manager.executor.submit(
        process_download, url, file_name, user_id, task_id, msg
    )

async def speedtest_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """FIXED Speedtest command with better error handling"""
    user = update.effective_user

    msg = await update.message.reply_text(
        "🌐 **Network Speed Test**\n\n"
        "🔄 **Status:** Initializing Ookla Speedtest...\n"
        "⏳ This may take 30-90 seconds"
    )

    # Check/install speedtest 
    await msg.edit_text(
        "🌐 **Network Speed Test**\n\n"
        "🔄 **Status:** Verifying speedtest installation...\n"
        "🏗️ Installing if needed (architecture: " + speedtest.detect_architecture() + ")"
    )

    if not speedtest.install_speedtest():
        await msg.edit_text(
            "❌ **Speed Test Failed**\n\n"
            "Could not install speedtest-cli for your system architecture.\n"
            f"**Architecture:** {speedtest.detect_architecture()}\n"
            "**Solution:** Contact administrator or try again later"
        )
        return

    await msg.edit_text(
        "🌐 **Network Speed Test**\n\n"
        "🔄 **Status:** Running comprehensive speed test...\n"
        "📡 Testing download speed\n"
        "📤 Testing upload speed\n"
        "🏓 Measuring latency\n"
        "⏳ Please wait up to 90 seconds..."
    )

    # Run speedtest in executor to avoid blocking
    result = await asyncio.get_event_loop().run_in_executor(
        None, speedtest.run_speedtest
    )

    if result['success']:
        # Get speed rating
        rating = get_speed_rating(result['download'])

        message = f"""
🌐 **Network Speed Test Results**

📊 **Connection Quality:**
📥 **Download:** {result['download']:.1f} Mbps
📤 **Upload:** {result['upload']:.1f} Mbps
🏓 **Latency:** {result['ping']:.1f} ms

🌍 **Server Information:**
📡 **Server:** {result['server']}
📍 **Location:** {result.get('location', 'Unknown')}
🏢 **ISP:** {result['isp']}

⚡ **Performance Rating:**
{rating}

💡 **Bot Settings:**
• Speed limit per user: {MAX_SPEED_MBPS} MB/s
• Max concurrent downloads: {MAX_CONCURRENT} files
• System architecture: {speedtest.detect_architecture()}
• Your connection can handle bot operations efficiently
"""
    else:
        message = f"""
❌ **Speed Test Failed**

**Error:** {result.get('error', 'Unknown error')}
**Architecture:** {speedtest.detect_architecture()}

💡 **Troubleshooting:**
• Check internet connection
• System may need compatible speedtest binary
• Try again in a few minutes
• Contact administrator if problem persists

**Alternative:** You can still use the bot for file downloads
"""

    await msg.edit_text(message, parse_mode='Markdown')

def get_speed_rating(speed_mbps):
    """Get speed rating based on download speed"""
    if speed_mbps >= 100:
        return "🚀 **Excellent** - Ultra-high speed connection"
    elif speed_mbps >= 50:
        return "⚡ **Very Good** - High speed connection"
    elif speed_mbps >= 25:
        return "✅ **Good** - Fast and reliable connection"
    elif speed_mbps >= 10:
        return "⚠️ **Average** - Moderate speed connection"
    else:
        return "🐌 **Slow** - Consider upgrading your connection"

def process_download(url, file_name, user_id, task_id, message):
    """Process download and upload professionally"""
    file_path = f"/app/downloads/{file_name}"

    try:
        # Update status to downloading
        asyncio.create_task(message.edit_text(
            f"📥 **Download in Progress**\n\n"
            f"📄 **File:** `{file_name}`\n"
            f"🌐 **Source:** Processing...\n"
            f"📊 **Status:** Retrieving file data",
            parse_mode='Markdown'
        ))

        response = requests.get(url, stream=True, timeout=300)
        response.raise_for_status()

        total_size = int(response.headers.get('content-length', 0))
        downloaded = 0

        # Download with speed limiting
        with open(file_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)
                    downloaded += len(chunk)
                    # Apply speed limit
                    time.sleep(8192 / (MAX_SPEED_MBPS * 1024 * 1024))

        # Update status to uploading
        asyncio.create_task(message.edit_text(
            f"☁️ **Uploading to Cloud Storage**\n\n"
            f"📄 **File:** `{file_name}`\n"
            f"📦 **Size:** {downloaded/(1024*1024):.1f} MB\n"
            f"🔄 **Status:** Transferring to secure storage",
            parse_mode='Markdown'
        ))

        # Upload to Google Drive
        file_id, share_link = storage_manager.upload_file(file_path, file_name)

        if file_id and share_link:
            # Cleanup local file
            try:
                os.remove(file_path)
            except:
                pass

            # Success message
            asyncio.create_task(message.edit_text(
                f"✅ **Process Completed Successfully!**\n\n"
                f"📄 **File:** `{file_name}`\n"
                f"📦 **Size:** {downloaded/(1024*1024):.1f} MB\n"
                f"🔗 **Access Link:** [Open File]({share_link})\n\n"
                f"🗑️ **Local cleanup completed** ✅",
                parse_mode='Markdown'
            ))
        else:
            raise Exception("Cloud storage upload failed")

    except Exception as e:
        # Cleanup on error
        try:
            if os.path.exists(file_path):
                os.remove(file_path)
        except:
            pass

        asyncio.create_task(message.edit_text(
            f"❌ **Process Failed**\n\n"
            f"📄 **File:** `{file_name}`\n"
            f"🚫 **Error:** {str(e)[:100]}...\n\n"
            f"💡 **Suggestion:** Verify link and try again"
        ))

    finally:
        download_manager.remove_download(user_id, task_id)

async def stats_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Enhanced stats command"""
    user = update.effective_user
    user_downloads = download_manager.active_downloads.get(user.id, [])

    message = f"📊 **Account Statistics - {user.first_name}**\n\n"

    message += f"🚀 **Current Status:**\n"
    message += f"📊 Active processes: {len(user_downloads)}/{MAX_CONCURRENT}\n"
    message += f"⚡ Speed allocation: {MAX_SPEED_MBPS} MB/s\n\n"

    if storage_manager.service:
        message += f"☁️ **Cloud Storage:** ✅ Connected & Active\n"
    else:
        message += f"☁️ **Cloud Storage:** ❌ Not connected (use /auth)\n"

    message += f"🌐 **Network Tools:** Speedtest available (/speedtest)\n"

    # System info
    oauth_port = os.getenv('OAUTH_PORT', '8080')
    arch = speedtest.detect_architecture()
    message += f"🔌 **OAuth Port:** {oauth_port}\n"
    message += f"🏗️ **Architecture:** {arch}\n"

    if is_owner(user.username):
        message += f"\n🔧 **Administrator Access:** Active\n"
        message += f"⚙️ **Advanced tools:** Available via /env\n"

    message += f"\n💡 **System optimized for high-performance file processing**"

    await update.message.reply_text(message, parse_mode='Markdown')

# Inline query handler for BotFather support
async def inline_query(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle inline queries for BotFather integration"""
    query = update.inline_query.query.lower().strip()

    results = []

    # Speed test inline
    if query.startswith('speed') or query.startswith('test'):
        results.append(
            InlineQueryResultArticle(
                id='speedtest',
                title='🌐 Network Speed Test',
                description='Test your internet connection speed with Ookla',
                input_message_content=InputTextMessageContent(
                    message_text='/speedtest',
                    parse_mode='Markdown'
                )
            )
        )

    # Auth inline
    if query.startswith('auth') or query.startswith('connect'):
        results.append(
            InlineQueryResultArticle(
                id='auth',
                title='🔐 Cloud Storage Authentication',
                description='Connect to Google Drive cloud storage',
                input_message_content=InputTextMessageContent(
                    message_text='/auth',
                    parse_mode='Markdown'
                )
            )
        )

    # Stats inline
    if query.startswith('stats') or query.startswith('info'):
        results.append(
            InlineQueryResultArticle(
                id='stats',
                title='📊 Account Statistics',
                description='View your account statistics and system info',
                input_message_content=InputTextMessageContent(
                    message_text='/stats',
                    parse_mode='Markdown'
                )
            )
        )

    # Help or default
    if not results or query.startswith('help') or query == '':
        available_commands = """🚀 **Available Commands:**

/auth - Connect cloud storage
/d [link] - Download and upload file  
/speedtest - Network speed test with Ookla
/stats - View account statistics

💡 **Inline Usage:**
Type @botname + command in any chat for quick access

🎯 **Features:**
• High-speed file downloads
• Auto Google Drive upload  
• Network diagnostics
• Professional interface"""

        results.append(
            InlineQueryResultArticle(
                id='help',
                title='🎯 Bot Commands & Features',
                description='View all available bot commands and features',
                input_message_content=InputTextMessageContent(
                    message_text=available_commands,
                    parse_mode='Markdown'
                )
            )
        )

    await update.inline_query.answer(results)

# Owner-only commands (@zalhera)
async def env_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Owner-only environment management"""
    if not await owner_only(update, context):
        return

    if not context.args:
        # Show current environment (masked)
        try:
            with open(ENV_FILE, 'r') as f:
                env_content = f.read()

            masked_env = ""
            for line in env_content.split('\n'):
                if '=' in line and not line.startswith('#'):
                    key, value = line.split('=', 1)
                    if any(secret in key.upper() for secret in ['TOKEN', 'SECRET', 'PASSWORD']):
                        masked_value = value[:4] + '*' * (len(value) - 4) if len(value) > 4 else '****'
                        masked_env += f"{key}={masked_value}\n"
                    else:
                        masked_env += f"{line}\n"
                else:
                    masked_env += f"{line}\n"

            message = f"🔧 **System Configuration (Secured)**\n\n"
            message += f"```\n{masked_env}```\n\n"
            message += f"**Available Commands:**\n"
            message += f"`/env get KEY` - Retrieve specific value\n"
            message += f"`/env set KEY VALUE` - Update configuration\n"
            message += f"`/env reload` - Refresh system settings\n"

        except Exception as e:
            message = f"❌ Configuration access error: {e}"

        await update.message.reply_text(message, parse_mode='Markdown')
        return

    action = context.args[0].lower()

    if action == 'get':
        if len(context.args) < 2:
            await update.message.reply_text("⚠️ Usage: `/env get VARIABLE_NAME`")
            return

        key = context.args[1]
        value = os.getenv(key, 'NOT_CONFIGURED')

        # Mask sensitive values
        if any(secret in key.upper() for secret in ['TOKEN', 'SECRET', 'PASSWORD']):
            masked_value = value[:4] + '*' * (len(value) - 4) if len(value) > 4 else '****'
            await update.message.reply_text(f"🔧 `{key}` = `{masked_value}`", parse_mode='Markdown')
        else:
            await update.message.reply_text(f"🔧 `{key}` = `{value}`", parse_mode='Markdown')

    elif action == 'set':
        if len(context.args) < 3:
            await update.message.reply_text("⚠️ Usage: `/env set VARIABLE_NAME VALUE`")
            return

        key = context.args[1]
        value = ' '.join(context.args[2:])

        try:
            # Read current environment variables
            env_vars = {}
            if os.path.exists(ENV_FILE):
                with open(ENV_FILE, 'r') as f:
                    for line in f:
                        line = line.strip()
                        if '=' in line and not line.startswith('#'):
                            k, v = line.split('=', 1)
                            env_vars[k] = v

            # Update the value
            env_vars[key] = value

            # Write back to file
            with open(ENV_FILE, 'w') as f:
                f.write("# System Configuration\n")
                for k, v in env_vars.items():
                    f.write(f"{k}={v}\n")

            # Update current environment
            os.environ[key] = value

            await update.message.reply_text(f"✅ Configuration updated: `{key}`", parse_mode='Markdown')

        except Exception as e:
            await update.message.reply_text(f"❌ Update failed: {e}")

    elif action == 'reload':
        try:
            # Reload environment from file
            if os.path.exists(ENV_FILE):
                with open(ENV_FILE, 'r') as f:
                    for line in f:
                        line = line.strip()
                        if '=' in line and not line.startswith('#'):
                            key, value = line.split('=', 1)
                            os.environ[key] = value

            await update.message.reply_text("✅ Configuration refreshed successfully")

        except Exception as e:
            await update.message.reply_text(f"❌ Refresh failed: {e}")

    else:
        await update.message.reply_text("⚠️ Available actions: get, set, reload")

async def restart_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Owner-only restart command"""
    if not await owner_only(update, context):
        return

    await update.message.reply_text(
        "🔄 **System Restart Initiated**\n\n"
        "Service will be back online within 30 seconds"
    )

    # Give time for message to send
    await asyncio.sleep(2)

    # Exit to trigger container restart
    os._exit(0)

def main():
    """Main application entry point with ALL FIXES"""
    if not BOT_TOKEN:
        logger.error("❌ BOT_TOKEN not configured")
        sys.exit(1)

    logger.info("🚀 Starting FULLY FIXED Advanced File Manager Bot...")
    logger.info(f"👑 Administrator: @{OWNER_USERNAME}")
    logger.info(f"⚡ Speed limit: {MAX_SPEED_MBPS} MB/s")
    logger.info(f"📊 Concurrent limit: {MAX_CONCURRENT}")
    logger.info(f"🌐 OAuth port: {os.getenv('OAUTH_PORT', '8080')}")
    logger.info(f"🏗️ System architecture: {speedtest.detect_architecture()}")

    # Create Telegram application with timeout settings
    app = Application.builder()\
        .token(BOT_TOKEN)\
        .connect_timeout(30)\
        .read_timeout(30)\
        .write_timeout(30)\
        .build()

    # Standard commands
    app.add_handler(CommandHandler("start", start_command))
    app.add_handler(CommandHandler("auth", auth_command))
    app.add_handler(CommandHandler("code", code_command))
    app.add_handler(CommandHandler("d", download_command))
    app.add_handler(CommandHandler("speedtest", speedtest_command))
    app.add_handler(CommandHandler("stats", stats_command))

    # Inline query handler
    app.add_handler(InlineQueryHandler(inline_query))

    # Administrator commands (@zalhera only)
    app.add_handler(CommandHandler("env", env_command))
    app.add_handler(CommandHandler("restart", restart_command))

    logger.info("✅ System initialization complete with ALL FIXES!")
    logger.info("🔗 Bot ready for inline queries and file processing")
    logger.info("🛠️ Platform requirement: FIXED (using built-in module)")
    logger.info("🛠️ OAuth2 response_type conflict: FIXED")
    logger.info("🏗️ Speedtest architecture detection: IMPLEMENTED")
    logger.info("🐳 Docker health check format: FIXED")

    # Start the bot
    app.run_polling(drop_pending_updates=True)

if __name__ == "__main__":
    main()
