#!/bin/bash
echo "🔨 Building OAuth2 Bot Image"
echo "============================"
cd "$(dirname "$0")"

if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

IMAGE_NAME=${IMAGE_NAME:-"bot-tele-3:latest"}

echo "Building OAuth2-enabled image: ${IMAGE_NAME}"
echo "Features: Client ID authentication, no credentials.json"
echo ""

if docker build -t ${IMAGE_NAME} .; then
    echo ""
    echo "✅ OAuth2 bot image built successfully!"
    echo "🖼️ Image: ${IMAGE_NAME}"
    echo "🔑 Features: OAuth2 Client ID authentication"
    echo "❌ No credentials.json file needed"
    echo ""
    echo "🚀 Start: ./start.sh"
else
    echo "❌ Build failed!"
    exit 1
fi
