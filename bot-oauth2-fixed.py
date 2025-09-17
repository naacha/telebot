#!/usr/bin/env python3
"""
Telegram Leech Bot - Fixed OAuth2 Implementation
Features:
- Working Google Drive OAuth2 with Client ID
- Speed limiting (5 MB/s per user)
- Concurrent limiting (2 downloads per user)
- Auto cleanup after upload
- Robust error handling
"""

import os
import sys
import asyncio
import sqlite3
import threading
import time
import requests
import shutil
import subprocess
import json
import logging
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
import signal
import tempfile
import webbrowser
from urllib.parse import urlencode
import http.server
import socketserver
from threading import Thread

# Telegram Bot imports
try:
    from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
    from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes, CallbackQueryHandler
    print("✅ Telegram library imported successfully")
except ImportError as e:
    print(f"❌ Failed to import telegram library: {e}")
    sys.exit(1)

# Google Drive API imports
try:
    from googleapiclient.discovery import build
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from google_auth_oauthlib.flow import Flow
    from googleapiclient.http import MediaFileUpload
    print("✅ Google API libraries imported successfully")
except ImportError as e:
    print(f"❌ Failed to import Google API libraries: {e}")
    print("Install with: pip install google-api-python-client google-auth-oauthlib")
    sys.exit(1)

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

# Configuration from environment variables
BOT_TOKEN = os.getenv('BOT_TOKEN')
REQUIRED_CHANNEL = os.getenv('REQUIRED_CHANNEL', '@YourChannel')
DOWNLOAD_LIMIT_GB = int(os.getenv('DOWNLOAD_LIMIT_GB', '200'))

# Google Drive OAuth2 Configuration
GOOGLE_CLIENT_ID = os.getenv('GOOGLE_CLIENT_ID')
GOOGLE_CLIENT_SECRET = os.getenv('GOOGLE_CLIENT_SECRET') 
GOOGLE_REDIRECT_URI = os.getenv('GOOGLE_REDIRECT_URI', 'http://localhost:8080')
GOOGLE_SCOPES = ['https://www.googleapis.com/auth/drive.file']

# Speed and Concurrent Limiting
MAX_CONCURRENT_DOWNLOADS_PER_USER = int(os.getenv('MAX_CONCURRENT_DOWNLOADS_PER_USER', '2'))
MAX_DOWNLOAD_SPEED_PER_USER_MBPS = float(os.getenv('MAX_DOWNLOAD_SPEED_PER_USER_MBPS', '5'))
CHUNK_SIZE = int(os.getenv('CHUNK_SIZE', '8192'))

# System settings
ROOT_MODE = os.getenv('ROOT_MODE', 'enabled').lower() == 'enabled'
DATABASE_PATH = os.getenv('DATABASE_PATH', '/app/data/bot_database.db')
TOKEN_FILE_PATH = '/app/data/google_token.json'

# Ensure required directories exist
os.makedirs(os.path.dirname(DATABASE_PATH), exist_ok=True)
os.makedirs('/app/downloads', exist_ok=True)
os.makedirs('/app/logs', exist_ok=True)

class SimpleOAuthHandler(http.server.BaseHTTPRequestHandler):
    """Simple HTTP handler for OAuth2 callback"""
    
    def do_GET(self):
        """Handle GET request for OAuth callback"""
        if self.path.startswith('/?code='):
            # Extract authorization code
            auth_code = self.path.split('code=')[1].split('&')[0]
            self.server.auth_code = auth_code
            
            # Send success response
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b"""
            <html>
            <head><title>Authorization Successful</title></head>
            <body>
            <h2>✅ Authorization Successful!</h2>
            <p>You can close this window and return to Telegram.</p>
            <script>window.close();</script>
            </body>
            </html>
            """)
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        """Suppress default logging"""
        pass

@dataclass
class DownloadTask:
    user_id: int
    task_id: str
    url: str
    file_name: str
    download_type: str
    allocated_speed_mbps: float = 0.0
    progress: float = 0.0
    downloaded_bytes: int = 0
    total_bytes: int = 0
    status: str = 'starting'

class GoogleDriveManager:
    """Fixed Google Drive manager with simplified OAuth2"""
    
    def __init__(self):
        self.service = None
        self.credentials = None
        self.initialize_service()
    
    def initialize_service(self):
        """Initialize Google Drive service"""
        try:
            # Load existing credentials if available
            if os.path.exists(TOKEN_FILE_PATH):
                with open(TOKEN_FILE_PATH, 'r') as f:
                    creds_data = json.load(f)
                
                self.credentials = Credentials(
                    token=creds_data.get('token'),
                    refresh_token=creds_data.get('refresh_token'),
                    client_id=GOOGLE_CLIENT_ID,
                    client_secret=GOOGLE_CLIENT_SECRET,
                    token_uri='https://oauth2.googleapis.com/token',
                    scopes=GOOGLE_SCOPES
                )
                
                # Refresh if expired
                if self.credentials.expired and self.credentials.refresh_token:
                    self.credentials.refresh(Request())
                    self.save_credentials()
            
            if self.credentials and self.credentials.valid:
                self.service = build('drive', 'v3', credentials=self.credentials)
                logger.info("✅ Google Drive service initialized")
            else:
                logger.warning("⚠️ Google Drive not authenticated. Use /auth command.")
                
        except Exception as e:
            logger.error(f"❌ Failed to initialize Google Drive service: {e}")
    
    def get_auth_url(self):
        """Get authorization URL for OAuth2 flow"""
        try:
            if not GOOGLE_CLIENT_ID or not GOOGLE_CLIENT_SECRET:
                return None, "GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET must be configured"
            
            # Create OAuth2 flow
            flow = Flow.from_client_config(
                {
                    "web": {
                        "client_id": GOOGLE_CLIENT_ID,
                        "client_secret": GOOGLE_CLIENT_SECRET,
                        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                        "token_uri": "https://oauth2.googleapis.com/token",
                        "redirect_uris": [GOOGLE_REDIRECT_URI]
                    }
                },
                scopes=GOOGLE_SCOPES
            )
            
            flow.redirect_uri = GOOGLE_REDIRECT_URI
            
            auth_url, _ = flow.authorization_url(
                access_type='offline',
                prompt='consent'
            )
            
            return auth_url, None
            
        except Exception as e:
            logger.error(f"❌ Failed to create auth URL: {e}")
            return None, str(e)
    
    def authenticate_with_code(self, auth_code):
        """Complete authentication with authorization code"""
        try:
            # Create OAuth2 flow
            flow = Flow.from_client_config(
                {
                    "web": {
                        "client_id": GOOGLE_CLIENT_ID,
                        "client_secret": GOOGLE_CLIENT_SECRET,
                        "auth_uri": "https://accounts.google.com/o/oauth2/auth", 
                        "token_uri": "https://oauth2.googleapis.com/token",
                        "redirect_uris": [GOOGLE_REDIRECT_URI]
                    }
                },
                scopes=GOOGLE_SCOPES
            )
            
            flow.redirect_uri = GOOGLE_REDIRECT_URI
            
            # Exchange code for token
            flow.fetch_token(code=auth_code)
            self.credentials = flow.credentials
            
            # Save credentials
            self.save_credentials()
            
            # Initialize service
            self.service = build('drive', 'v3', credentials=self.credentials)
            
            logger.info("✅ OAuth2 authentication completed successfully")
            return True, None
            
        except Exception as e:
            logger.error(f"❌ Authentication failed: {e}")
            return False, str(e)
    
    def save_credentials(self):
        """Save credentials to file"""
        try:
            creds_data = {
                'token': self.credentials.token,
                'refresh_token': self.credentials.refresh_token,
                'client_id': self.credentials.client_id,
                'client_secret': self.credentials.client_secret,
                'scopes': self.credentials.scopes
            }
            
            os.makedirs(os.path.dirname(TOKEN_FILE_PATH), exist_ok=True)
            with open(TOKEN_FILE_PATH, 'w') as f:
                json.dump(creds_data, f)
            
            # Set secure permissions
            os.chmod(TOKEN_FILE_PATH, 0o600)
            logger.info("💾 Credentials saved successfully")
            
        except Exception as e:
            logger.error(f"❌ Failed to save credentials: {e}")
    
    def upload_file(self, file_path: str, file_name: str) -> Tuple[Optional[str], Optional[str]]:
        """Upload file to Google Drive"""
        if not self.service:
            logger.error("❌ Google Drive service not initialized")
            return None, None
        
        try:
            # File metadata
            file_metadata = {
                'name': file_name,
                'parents': []
            }
            
            # Upload file
            media = MediaFileUpload(file_path, resumable=True)
            
            file = self.service.files().create(
                body=file_metadata,
                media_body=media,
                fields='id'
            ).execute()
            
            file_id = file.get('id')
            
            # Make file public
            permission = {
                'type': 'anyone',
                'role': 'reader'
            }
            
            self.service.permissions().create(
                fileId=file_id,
                body=permission
            ).execute()
            
            # Generate share link
            share_link = f"https://drive.google.com/file/d/{file_id}/view"
            
            logger.info(f"✅ File uploaded: {file_name}")
            return file_id, share_link
            
        except Exception as e:
            logger.error(f"❌ Upload failed: {e}")
            return None, None

class SpeedLimitedDownloader:
    """Download manager with speed limiting"""
    
    def __init__(self, speed_limit_mbps: float):
        self.speed_limit_bps = speed_limit_mbps * 1024 * 1024
        self.downloaded = 0
        self.start_time = time.time()
    
    def download_with_progress(self, url: str, file_path: str, progress_callback=None) -> bool:
        """Download file with speed limiting"""
        try:
            response = requests.get(url, stream=True)
            response.raise_for_status()
            
            total_size = int(response.headers.get('content-length', 0))
            
            with open(file_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=CHUNK_SIZE):
                    if chunk:
                        f.write(chunk)
                        self.downloaded += len(chunk)
                        
                        # Apply speed limit
                        self._apply_speed_limit(len(chunk))
                        
                        # Progress callback
                        if progress_callback and total_size > 0:
                            progress = (self.downloaded / total_size) * 100
                            speed = self._calculate_speed()
                            progress_callback(progress, self.downloaded, total_size, speed)
            
            return True
            
        except Exception as e:
            logger.error(f"❌ Download failed: {e}")
            return False
    
    def _apply_speed_limit(self, chunk_size: int):
        """Apply speed limiting"""
        if self.speed_limit_bps <= 0:
            return
        
        elapsed = time.time() - self.start_time
        if elapsed > 0:
            current_speed = self.downloaded / elapsed
            if current_speed > self.speed_limit_bps:
                target_time = self.downloaded / self.speed_limit_bps
                sleep_time = target_time - elapsed
                if sleep_time > 0:
                    time.sleep(sleep_time)
    
    def _calculate_speed(self) -> float:
        """Calculate current speed in MB/s"""
        elapsed = time.time() - self.start_time
        if elapsed > 0:
            return (self.downloaded / elapsed) / (1024 * 1024)
        return 0.0

class DownloadManager:
    """Download queue manager"""
    
    def __init__(self):
        self.active_downloads: Dict[int, List[DownloadTask]] = {}
        self.executor = ThreadPoolExecutor(max_workers=10)
        self.lock = threading.Lock()
    
    def can_add_download(self, user_id: int) -> bool:
        """Check if user can add more downloads"""
        with self.lock:
            user_downloads = self.active_downloads.get(user_id, [])
            return len(user_downloads) < MAX_CONCURRENT_DOWNLOADS_PER_USER
    
    def add_download_task(self, task: DownloadTask) -> bool:
        """Add download task"""
        if not self.can_add_download(task.user_id):
            return False
        
        with self.lock:
            if task.user_id not in self.active_downloads:
                self.active_downloads[task.user_id] = []
            
            self.active_downloads[task.user_id].append(task)
            self._recalculate_speeds(task.user_id)
        
        return True
    
    def remove_download_task(self, user_id: int, task_id: str):
        """Remove completed task"""
        with self.lock:
            if user_id in self.active_downloads:
                self.active_downloads[user_id] = [
                    task for task in self.active_downloads[user_id] 
                    if task.task_id != task_id
                ]
                if not self.active_downloads[user_id]:
                    del self.active_downloads[user_id]
                else:
                    self._recalculate_speeds(user_id)
    
    def _recalculate_speeds(self, user_id: int):
        """Recalculate speed allocation"""
        if user_id not in self.active_downloads:
            return
        
        downloads = self.active_downloads[user_id]
        if downloads:
            speed_per_download = MAX_DOWNLOAD_SPEED_PER_USER_MBPS / len(downloads)
            for task in downloads:
                task.allocated_speed_mbps = speed_per_download
    
    def get_user_downloads(self, user_id: int) -> List[DownloadTask]:
        """Get user's active downloads"""
        with self.lock:
            return self.active_downloads.get(user_id, []).copy()

class DatabaseManager:
    """Simple database manager"""
    
    def __init__(self, db_path: str):
        self.db_path = db_path
        self.init_database()
    
    def init_database(self):
        """Initialize database"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS downloads (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id INTEGER NOT NULL,
                    file_name TEXT NOT NULL,
                    file_size_mb REAL NOT NULL,
                    download_type TEXT NOT NULL,
                    upload_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    file_id TEXT,
                    share_link TEXT
                )
            ''')
            conn.commit()
    
    def add_download_record(self, user_id: int, file_name: str, file_size_mb: float, 
                          download_type: str, file_id: str = None, share_link: str = None):
        """Add download record"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            cursor.execute('''
                INSERT INTO downloads (user_id, file_name, file_size_mb, download_type, file_id, share_link)
                VALUES (?, ?, ?, ?, ?, ?)
            ''', (user_id, file_name, file_size_mb, download_type, file_id, share_link))
            conn.commit()
    
    def get_user_stats(self, user_id: int) -> dict:
        """Get user statistics"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.cursor()
            cursor.execute('''
                SELECT COUNT(*), COALESCE(SUM(file_size_mb), 0)
                FROM downloads WHERE user_id = ?
            ''', (user_id,))
            total_downloads, total_size_mb = cursor.fetchone()
            
            return {
                'total_downloads': total_downloads,
                'total_size_mb': total_size_mb
            }

# Global instances
drive_manager = GoogleDriveManager()
download_manager = DownloadManager()
db = DatabaseManager(DATABASE_PATH)

# Bot command handlers
async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Start command"""
    user = update.effective_user
    stats = db.get_user_stats(user.id)
    active_downloads = len(download_manager.get_user_downloads(user.id))
    
    message = f"""
🎉 Selamat datang {user.first_name}!

🤖 Bot Leech Google Drive (Fixed OAuth2)
📁 Upload otomatis ke Google Drive
🗑️ Auto cleanup file setelah upload

🚀 Download Limits:
📊 Max concurrent: {MAX_CONCURRENT_DOWNLOADS_PER_USER} downloads
🌐 Max speed: {MAX_DOWNLOAD_SPEED_PER_USER_MBPS} MB/s per user
📈 Current active: {active_downloads}/{MAX_CONCURRENT_DOWNLOADS_PER_USER}

📋 Commands:
/help - Bantuan
/d [link] - Download file  
/stats - Statistik
/auth - Setup Google Drive (OAuth2)

💡 Speed terbagi otomatis untuk multiple downloads!
🔑 OAuth2 authentication - no credentials.json needed!
"""
    
    await update.message.reply_text(message)

async def auth_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """OAuth2 authentication command"""
    user = update.effective_user
    
    if not GOOGLE_CLIENT_ID or not GOOGLE_CLIENT_SECRET:
        await update.message.reply_text(
            "❌ OAuth2 belum dikonfigurasi!\n"
            "Admin perlu set GOOGLE_CLIENT_ID dan GOOGLE_CLIENT_SECRET"
        )
        return
    
    # Check if already authenticated
    if drive_manager.service:
        await update.message.reply_text(
            "✅ Google Drive sudah terautentikasi!\n"
            "Bot siap menerima downloads."
        )
        return
    
    # Get authorization URL
    auth_url, error = drive_manager.get_auth_url()
    if error:
        await update.message.reply_text(f"❌ Error getting auth URL: {error}")
        return
    
    # Send authorization instructions
    message = f"""
🔑 **Google Drive OAuth2 Setup**

📝 **Langkah Authentication:**

1️⃣ Klik link di bawah ini:
{auth_url}

2️⃣ Login dengan Google account
3️⃣ Grant permissions untuk Drive access
4️⃣ Copy authorization code yang muncul
5️⃣ Send code dengan: `/code [your-code-here]`

💡 **Contoh:** `/code 4/0AdQt8qi...`

⚠️ **Note:** Code hanya valid 10 menit!
"""
    
    await update.message.reply_text(message, parse_mode='Markdown')

async def code_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle authorization code"""
    user = update.effective_user
    
    if not context.args:
        await update.message.reply_text(
            "❌ Format salah!\n"
            "Gunakan: `/code [authorization-code]`\n"
            "Get code dari /auth link"
        )
        return
    
    auth_code = context.args[0]
    
    # Process authentication
    processing_msg = await update.message.reply_text("🔄 Processing authentication...")
    
    success, error = drive_manager.authenticate_with_code(auth_code)
    
    if success:
        await processing_msg.edit_text(
            "✅ **Authentication Successful!**\n\n"
            "🚀 Google Drive berhasil terhubung\n"
            "📝 Bot siap untuk download dan upload\n"
            "💡 Test dengan: `/d [link]`"
        )
    else:
        await processing_msg.edit_text(
            f"❌ **Authentication Failed**\n\n"
            f"Error: {error}\n\n"
            f"💡 Coba lagi dengan /auth"
        )

async def download_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Download command"""
    user = update.effective_user
    
    if not context.args:
        await update.message.reply_text(
            "❌ Format salah!\n"
            "Gunakan: `/d [link]`\n"
            "Contoh: `/d https://example.com/file.zip`"
        )
        return
    
    url = context.args[0]
    
    # Check authentication
    if not drive_manager.service:
        await update.message.reply_text(
            "❌ Google Drive belum terautentikasi!\n"
            "Setup dengan: /auth"
        )
        return
    
    # Check download limits
    if not download_manager.can_add_download(user.id):
        active = len(download_manager.get_user_downloads(user.id))
        await update.message.reply_text(
            f"⚠️ Download limit tercapai!\n"
            f"Active: {active}/{MAX_CONCURRENT_DOWNLOADS_PER_USER}\n"
            f"Tunggu download selesai atau cek /stats"
        )
        return
    
    # Create download task
    task_id = f"{user.id}_{int(time.time())}"
    file_name = url.split('/')[-1] or f"download_{int(time.time())}"
    
    task = DownloadTask(
        user_id=user.id,
        task_id=task_id,
        url=url,
        file_name=file_name,
        download_type='direct'
    )
    
    if not download_manager.add_download_task(task):
        await update.message.reply_text("❌ Gagal add download ke queue!")
        return
    
    # Start download
    speed = task.allocated_speed_mbps or MAX_DOWNLOAD_SPEED_PER_USER_MBPS
    
    status_msg = await update.message.reply_text(
        f"🔄 Starting download...\n"
        f"📁 File: {file_name}\n"
        f"🌐 Speed limit: {speed:.1f} MB/s"
    )
    
    # Process in background
    download_manager.executor.submit(
        process_download, task, status_msg, context
    )

def process_download(task: DownloadTask, message, context):
    """Process download with upload"""
    try:
        file_path = f"/app/downloads/{task.file_name}"
        
        # Download
        downloader = SpeedLimitedDownloader(task.allocated_speed_mbps)
        
        def progress_callback(progress, downloaded, total, speed):
            if int(progress) % 10 == 0:  # Update every 10%
                asyncio.create_task(message.edit_text(
                    f"📥 Downloading: {task.file_name}\n"
                    f"🌐 Speed: {speed:.1f} MB/s\n"
                    f"📊 Progress: {progress:.1f}%\n"
                    f"💾 Downloaded: {downloaded/(1024*1024):.1f} MB"
                ))
        
        success = downloader.download_with_progress(task.url, file_path, progress_callback)
        
        if not success:
            raise Exception("Download failed")
        
        # Upload to Google Drive
        asyncio.create_task(message.edit_text(
            f"☁️ Uploading to Google Drive...\n"
            f"📁 {task.file_name}"
        ))
        
        file_id, share_link = drive_manager.upload_file(file_path, task.file_name)
        
        if file_id and share_link:
            # Success - cleanup file
            try:
                os.remove(file_path)
                logger.info(f"🗑️ File deleted: {file_path}")
            except:
                pass
            
            # Save record
            file_size_mb = os.path.getsize(file_path) / (1024*1024) if os.path.exists(file_path) else 0
            db.add_download_record(
                task.user_id, task.file_name, file_size_mb, 
                task.download_type, file_id, share_link
            )
            
            # Success message
            asyncio.create_task(message.edit_text(
                f"✅ **Download Successful!**\n\n"
                f"📄 File: {task.file_name}\n"
                f"📦 Size: {file_size_mb:.1f} MB\n"
                f"🔗 [Google Drive Link]({share_link})\n\n"
                f"🗑️ Local file deleted automatically ✅",
                parse_mode='Markdown'
            ))
        else:
            raise Exception("Upload to Google Drive failed")
    
    except Exception as e:
        logger.error(f"❌ Download process failed: {e}")
        
        # Cleanup on error
        try:
            if os.path.exists(file_path):
                os.remove(file_path)
        except:
            pass
        
        asyncio.create_task(message.edit_text(
            f"❌ **Download Failed!**\n"
            f"📄 File: {task.file_name}\n"
            f"🚫 Error: {str(e)}"
        ))
    
    finally:
        # Remove from manager
        download_manager.remove_download_task(task.user_id, task.task_id)

async def stats_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Statistics command"""
    user = update.effective_user
    stats = db.get_user_stats(user.id)
    active_downloads = download_manager.get_user_downloads(user.id)
    
    message = f"📊 **Your Statistics**\n\n"
    
    # Download limits
    message += f"🚀 **Download Status:**\n"
    message += f"📊 Active: {len(active_downloads)}/{MAX_CONCURRENT_DOWNLOADS_PER_USER}\n"
    message += f"🌐 Speed limit: {MAX_DOWNLOAD_SPEED_PER_USER_MBPS} MB/s per user\n\n"
    
    # Active downloads
    if active_downloads:
        message += f"🔄 **Active Downloads:**\n"
        for task in active_downloads:
            message += f"• {task.file_name[:30]}... ({task.status})\n"
        message += "\n"
    
    # Overall stats
    message += f"📈 **Total Downloads:** {stats['total_downloads']}\n"
    message += f"📦 **Total Size:** {stats['total_size_mb']:.1f} MB\n\n"
    
    # Google Drive status
    if drive_manager.service:
        message += f"☁️ **Google Drive:** ✅ Connected (OAuth2)\n"
    else:
        message += f"☁️ **Google Drive:** ❌ Not connected (/auth)\n"
    
    await update.message.reply_text(message, parse_mode='Markdown')

def main():
    """Main function"""
    # Validate environment
    if not BOT_TOKEN:
        logger.error("❌ BOT_TOKEN not set")
        sys.exit(1)
    
    if not GOOGLE_CLIENT_ID or not GOOGLE_CLIENT_SECRET:
        logger.warning("⚠️ Google OAuth2 not configured (GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET)")
    
    logger.info("🚀 Starting Telegram Leech Bot with Fixed OAuth2...")
    logger.info(f"📊 Speed limit: {MAX_DOWNLOAD_SPEED_PER_USER_MBPS} MB/s per user")
    logger.info(f"🔢 Concurrent limit: {MAX_CONCURRENT_DOWNLOADS_PER_USER} per user")
    
    # Create application
    application = Application.builder().token(BOT_TOKEN).build()
    
    # Add handlers
    application.add_handler(CommandHandler("start", start_command))
    application.add_handler(CommandHandler("auth", auth_command))
    application.add_handler(CommandHandler("code", code_command))
    application.add_handler(CommandHandler("d", download_command))
    application.add_handler(CommandHandler("stats", stats_command))
    
    # Graceful shutdown
    def signal_handler(signum, frame):
        logger.info("🛑 Shutting down...")
        download_manager.executor.shutdown(wait=True)
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Start bot
    logger.info("✅ Bot started successfully!")
    application.run_polling(drop_pending_updates=True)

if __name__ == "__main__":
    main()