#!/bin/bash
echo "🚀 Starting Telegram Leech Bot (OAuth2 + Docker Direct)"
echo "======================================================"
cd "$(dirname "$0")"

# Load environment
if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "❌ Error: .env file not found!"
    echo "Run: cp .env.example .env && nano .env"
    exit 1
fi

# Validate OAuth2 configuration
if [ -z "$GOOGLE_CLIENT_ID" ] || [ -z "$GOOGLE_CLIENT_SECRET" ]; then
    echo "❌ Error: Google OAuth2 not configured!"
    echo "Required: GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET in .env"
    echo "📖 See: OAUTH2-SETUP-GUIDE.md"
    exit 1
fi

CONTAINER_NAME=${CONTAINER_NAME:-"leech-bot"}
IMAGE_NAME=${IMAGE_NAME:-"bot-tele-3:latest"}

echo "⚠️ WARNING: Container will run with FULL ROOT PRIVILEGES!"
echo "🔑 Features:"
echo "   • OAuth2 authentication (no credentials.json needed)"
echo "   • Speed limiting: 5 MB/s per user (auto-shared)"
echo "   • Concurrent limit: 2 downloads per user"
echo "   • Auto cleanup: Files deleted after upload"
echo "   • Automatic token management"
echo ""
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Start cancelled"
    exit 1
fi

# Stop and remove existing container
if docker ps -q -f name=${CONTAINER_NAME} > /dev/null; then
    echo "🛑 Stopping existing container..."
    docker stop ${CONTAINER_NAME} > /dev/null 2>&1
fi

if docker ps -aq -f name=${CONTAINER_NAME} > /dev/null; then
    echo "🗑️ Removing existing container..."
    docker rm ${CONTAINER_NAME} > /dev/null 2>&1
fi

# Build image if not exists
if ! docker images -q ${IMAGE_NAME} > /dev/null; then
    echo "🔨 Building Docker image..."
    ./build.sh
fi

echo "🚀 Starting bot with OAuth2 authentication..."

# Run container (NO credentials.json mount!)
docker run -d     --name ${CONTAINER_NAME}     --user root     --privileged     --restart unless-stopped     --env-file .env     -v $(pwd)/data:/app/data     -v $(pwd)/downloads:/app/downloads     -v $(pwd)/logs:/app/logs     -v $(pwd)/config:/app/config     -v /var/log/bot:/var/log/bot     -p 8080:8080     ${IMAGE_NAME}

sleep 3

if docker ps -q -f name=${CONTAINER_NAME} > /dev/null; then
    echo ""
    echo "✅ Bot started successfully with OAuth2!"
    echo "📊 Container: ${CONTAINER_NAME}"
    echo "🔑 Authentication: OAuth2 Client ID"
    echo "🔓 Running as: ROOT (UID: 0)"
    echo ""
    echo "📝 Next steps:"
    echo "   1. Send /start to bot in Telegram"
    echo "   2. Send /auth to complete OAuth2 setup"
    echo "   3. Test with /d [link]"
    echo ""
    echo "🔧 Management: ./status.sh, ./logs.sh, ./auth-test.sh"
else
    echo "❌ Failed to start container!"
    docker logs ${CONTAINER_NAME}
    exit 1
fi
